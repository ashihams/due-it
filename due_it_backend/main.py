from fastapi import FastAPI, Header, HTTPException, Query
from fastapi.responses import HTMLResponse
from firebase_admin import auth, firestore, initialize_app
from datetime import datetime, timezone, timedelta
from google import genai
from google.genai import types
from pydantic import BaseModel
from typing import Optional
import json
import os
import math
import logging
import requests
import base64
import asyncio
import concurrent.futures

import notion_service
import tinyfish_service

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

# Firebase Admin
try:
    initialize_app()
    db = firestore.client()
    logger.info("✅ Firebase Admin initialized")
except Exception as e:
    logger.error(f"❌ Firebase Admin init failed: {e}")
    raise

# Gemini (Google GenAI SDK)
try:
    gemini_key = os.environ.get("GEMINI_API_KEY")
    if not gemini_key:
        logger.error("❌ GEMINI_API_KEY not found in environment")
        raise ValueError("GEMINI_API_KEY environment variable is required")
    client = genai.Client(
        api_key=gemini_key,
        http_options={"api_version": "v1"},
    )
    logger.info("✅ Gemini AI configured")
except Exception as e:
    logger.error(f"❌ Gemini AI setup failed: {e}")
    raise

DAILY_CAPACITY_MINUTES = 120  # baseline for pressure


class DisconnectNotionRequest(BaseModel):
    uid: str


class GenerateDocRequest(BaseModel):
    """Body for POST /generate-doc (Flutter launchpad page creation)."""

    taskId: str
    title: str
    deadline: str
    schedule: list = []
    category: str = "personal"
    uid: Optional[str] = None


def _only_date(dt: datetime) -> datetime:
    """
    Normalize a datetime to midnight UTC (date-only semantics).
    """
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return datetime(dt.year, dt.month, dt.day, tzinfo=timezone.utc)


def _days_inclusive(start: datetime, end: datetime) -> int:
    """
    Inclusive day span between two datetimes, with a minimum of 1.
    Example: start=Mar 1, end=Mar 1 -> 1 day.
    """
    s = _only_date(start)
    e = _only_date(end)
    return max(1, (e - s).days + 1)


def _redistribute_schedule(schedule, start: datetime, deadline: datetime):
    """
    Distribute remaining (incomplete) microtasks from `start` until `deadline`.
    - Carries forward missed microtasks to today or future days.
    - Limits to max 5 microtasks per day.
    """
    if not schedule:
        return []

    today = _only_date(start)
    deadline_date = _only_date(deadline)
    today_str = today.strftime("%Y-%m-%d")
    deadline_str = deadline_date.strftime("%Y-%m-%d")

    missed_microtasks = []
    
    # 1. Collect unfinished microtasks from the past
    for day in schedule:
        day_date_str = day.get("date", "")
        if not day_date_str:
            continue
            
        if day_date_str < today_str:
            incomplete = []
            for mt in day.get("microtasks", []):
                if not mt.get("completed"):
                    missed_microtasks.append({
                        "title": mt.get("title", ""),
                        "completed": False
                    })
                else:
                    incomplete.append(mt)
            # Remove incomplete from the past day
            day["microtasks"] = incomplete

    if not missed_microtasks:
        return schedule
        
    # 2. Distribute missed_microtasks starting from today until deadline
    # Find active days (today to deadline) in schedule
    active_days = [day for day in schedule if today_str <= day.get("date", "") <= deadline_str]
    
    # If no active days exist (schedule ended before deadline?), create today
    if not active_days:
        today_plan = next((d for d in schedule if d.get("date") == today_str), None)
        if not today_plan:
            today_plan = {"date": today_str, "subtask": "Catch Up", "microtasks": []}
            schedule.append(today_plan)
        active_days = [today_plan]

    # Try to add to active days without exceeding 5
    for mt in missed_microtasks:
        added = False
        for day in active_days:
            if len(day.get("microtasks", [])) < 5:
                day["microtasks"].append(mt)
                added = True
                break
        
        if not added:
            # If all active days have >= 5, just add to today
            active_days[0]["microtasks"].append(mt)
            
    # Sort schedule chronologically
    schedule.sort(key=lambda x: x.get("date", ""))
    return schedule


def _compute_time_metrics(
    estimated_minutes: int,
    schedule: list,
    now: datetime,
    deadline: datetime,
):
    """
    Compute remainingMinutes, dailyRequiredMinutes, pressureScore, and riskScore
    based on current microtask completion and time until deadline.
    """
    total_microtasks = 0
    completed_count = 0
    for day in schedule:
        for mt in day.get("microtasks", []):
            total_microtasks += 1
            if mt.get("completed"):
                completed_count += 1

    if total_microtasks == 0:
        remaining_minutes = 0
    else:
        fraction_remaining = max(
            0.0, 1.0 - (completed_count / float(total_microtasks))
        )
        remaining_minutes = int(math.ceil(estimated_minutes * fraction_remaining))

    today = _only_date(now)
    deadline_date = _only_date(deadline)
    remaining_days = _days_inclusive(today, deadline_date)

    if remaining_minutes <= 0:
        daily_required = 0
    else:
        daily_required = int(math.ceil(remaining_minutes / remaining_days))

    pressure_score = round(
        (daily_required / float(DAILY_CAPACITY_MINUTES)) if DAILY_CAPACITY_MINUTES else 0.0,
        2,
    )

    deadline_proximity = min(1.0, 1.0 / float(remaining_days))
    risk_score = round(
        0.6 * min(pressure_score, 1.5) + 0.4 * deadline_proximity,
        2,
    )

    return {
        "remainingMinutes": remaining_minutes,
        "dailyRequiredMinutes": daily_required,
        "pressureScore": pressure_score,
        "riskScore": risk_score,
    }

def _get_notion_token(uid: str):
    """Fetch the user's Notion OAuth token from Firestore. Returns token string or None."""
    if not uid:
        return None
    try:
        user_doc = db.collection("users").document(uid).get()
        if not user_doc.exists:
            return None
        data = user_doc.to_dict() or {}
        return data.get("notionToken")
    except Exception as e:
        logger.warning(f"_get_notion_token: failed for uid={uid}: {e}")
        return None


def _generate_ai_plan_text(schedule: list) -> str:
    """Summarize AI schedule into a plain text AI Plan string."""
    if not schedule:
        return ""
    lines = []
    for day in schedule[:15]:  # limit to 15 days summary
        if not isinstance(day, dict):
            continue
        date = day.get("date", "")
        subtask = day.get("subtask", "")
        mts = day.get("microtasks") or []
        mt_titles = [m.get("title", "") for m in mts if isinstance(m, dict)]
        line = f"{date}: {subtask}"
        if mt_titles:
            line += f" — {', '.join(mt_titles[:3])}"
        lines.append(line)
    return "\n".join(lines)[:2000]


async def _scrape_and_populate(
    uid: str,
    task_id: str,
    title: str,
    category: str,
    notion_page_id: str,
    notion_token: str,
) -> None:
    import json, re
    try:
        logger.info(f"🔍 Starting TinyFish scrape for: {title}")
        cat = (category or "study").strip().lower()
        result = await asyncio.to_thread(
            tinyfish_service.scrape_resources, title, cat
        )
        logger.info(f"🔍 TinyFish raw result preview: {str(result.get('result', ''))[:500]}")
        if result.get("success"):
            logger.info("✅ TinyFish scrape complete")
            raw = result.get("result", "")

            # Robust resource parsing
            resources = []

            # If result is already a dict/list (TinyFish returned structured data)
            if isinstance(raw, (dict, list)):
                if isinstance(raw, list):
                    resources = raw
                elif isinstance(raw, dict) and "result" in raw:
                    resources = raw["result"] if isinstance(raw["result"], list) else []
            else:
                raw_str = str(raw)

                # Method 1: find JSON array directly
                try:
                    start = raw_str.find("[")
                    end = raw_str.rfind("]") + 1
                    if start >= 0 and end > start:
                        resources = json.loads(raw_str[start:end])
                except Exception:
                    pass

                # Method 2: find JSON object with result key
                if not resources:
                    try:
                        start = raw_str.find("{")
                        end = raw_str.rfind("}") + 1
                        if start >= 0 and end > start:
                            parsed = json.loads(raw_str[start:end])
                            if isinstance(parsed.get("result"), list):
                                resources = parsed["result"]
                    except Exception:
                        pass

                # Method 3: extract URLs with regex as fallback
                if not resources:
                    urls = re.findall(r'https?://[^\s\'"<>]+', raw_str)
                    titles = re.findall(r'"title":\s*"([^"]+)"', raw_str)
                    descs = re.findall(r'"description":\s*"([^"]+)"', raw_str)
                    for i, url in enumerate(urls[:5]):
                        resources.append({
                            "title": titles[i] if i < len(titles) else f"Resource {i+1}",
                            "url": url,
                            "description": descs[i] if i < len(descs) else ""
                        })

            logger.info(f"📦 Parsed resources count: {len(resources)}")
            if resources:
                logger.info(f"📦 First resource: {resources[0]}")
            else:
                logger.warning(f"⚠️ Could not parse resources. Raw result preview: {str(raw)[:300]}")

            db.collection("users").document(uid).collection("tasks").document(
                task_id
            ).update(
                {
                    "tinyfishResources": str(raw),
                    "resourcesScraped": True,
                }
            )
            logger.info(f"🎯 Adding resources to launchpad page: {notion_page_id}")
            if notion_service.add_resources_to_page(
                notion_page_id, notion_token, resources
            ):
                logger.info("✅ Resources added to Notion page")
            else:
                logger.warning("⚠️ Could not add resources to Notion page")
        else:
            logger.warning(
                "TinyFish scrape failed: %s",
                result.get("error", "unknown"),
            )
    except Exception as e:
        logger.warning(f"_scrape_and_populate error: {e}")


def _scrape_and_populate_sync(
    uid: str,
    task_id: str,
    title: str,
    category: str,
    notion_page_id: str,
    notion_token: str,
) -> None:
    import json, re
    try:
        logger.info(f"🔍 Starting TinyFish scrape (sync) for: {title}")
        cat = (category or "study").strip().lower()
        result = tinyfish_service.scrape_resources(title, cat)
        logger.info(f"🔍 TinyFish raw result preview: {str(result.get('result', ''))[:500]}")
        if result.get("success"):
            logger.info("✅ TinyFish scrape complete")
            raw = result.get("result", "")

            resources = []

            if isinstance(raw, (dict, list)):
                if isinstance(raw, list):
                    resources = raw
                elif isinstance(raw, dict) and "result" in raw:
                    resources = raw["result"] if isinstance(raw["result"], list) else []
            else:
                raw_str = str(raw)

                try:
                    start = raw_str.find("[")
                    end = raw_str.rfind("]") + 1
                    if start >= 0 and end > start:
                        resources = json.loads(raw_str[start:end])
                except Exception:
                    pass

                if not resources:
                    try:
                        start = raw_str.find("{")
                        end = raw_str.rfind("}") + 1
                        if start >= 0 and end > start:
                            parsed = json.loads(raw_str[start:end])
                            if isinstance(parsed.get("result"), list):
                                resources = parsed["result"]
                    except Exception:
                        pass

                if not resources:
                    urls = re.findall(r'https?://[^\s\'"<>]+', raw_str)
                    titles = re.findall(r'"title":\s*"([^"]+)"', raw_str)
                    descs = re.findall(r'"description":\s*"([^"]+)"', raw_str)
                    for i, url in enumerate(urls[:5]):
                        resources.append({
                            "title": titles[i] if i < len(titles) else f"Resource {i+1}",
                            "url": url,
                            "description": descs[i] if i < len(descs) else ""
                        })

            logger.info(f"📦 Parsed resources count: {len(resources)}")
            if resources:
                logger.info(f"📦 First resource: {resources[0]}")
            else:
                logger.warning(f"⚠️ Could not parse resources. Raw result preview: {str(raw)[:300]}")

            db.collection("users").document(uid).collection("tasks").document(
                task_id
            ).update(
                {
                    "tinyfishResources": str(raw),
                    "resourcesScraped": True,
                }
            )
            logger.info(f"🎯 Adding resources to launchpad page: {notion_page_id}")
            logger.info(f"Looking for resources placeholder in page: {notion_page_id}")
            if notion_service.add_resources_to_page(
                notion_page_id, notion_token, resources
            ):
                logger.info("✅ Resources added to Notion page")
            else:
                logger.warning("⚠️ Could not add resources to Notion page")
        else:
            logger.warning(
                "TinyFish scrape failed: %s",
                result.get("error", "unknown"),
            )
    except Exception as e:
        logger.warning(f"_scrape_and_populate_sync error: {e}")


@app.post("/health")
async def health():
    return {"status": "ok"}


@app.post("/test-notion-direct")
async def test_notion_direct(payload: dict):
    """Direct test - bypasses all auth and Firestore lookups"""
    notion_token = payload.get("notion_token")
    title = payload.get("title", "Test Page")
    parent_page_id = payload.get("parent_page_id")

    if not notion_token or not parent_page_id:
        return {"error": "notion_token and parent_page_id required"}

    import requests
    headers = {
        "Authorization": f"Bearer {notion_token}",
        "Notion-Version": "2022-06-28",
        "Content-Type": "application/json",
    }

    # Test 1: Can we read the workspace?
    me = requests.get("https://api.notion.com/v1/users/me", headers=headers)

    # Test 2: Can we create a page?
    body = {
        "parent": {"page_id": parent_page_id},
        "properties": {
            "title": {"title": [{"text": {"content": title}}]},
        },
        "children": [
            {
                "object": "block",
                "type": "paragraph",
                "paragraph": {
                    "rich_text": [{"text": {"content": "Test page created by DueIt"}}]
                },
            }
        ],
    }
    page = requests.post("https://api.notion.com/v1/pages", headers=headers, json=body)

    return {
        "user_status": me.status_code,
        "user_response": me.json(),
        "page_status": page.status_code,
        "page_response": page.json(),
    }


@app.get("/test-tinyfish")
async def test_tinyfish():
    """Test TinyFish API is working"""
    result = tinyfish_service.run_automation(
        url="https://example.com",
        goal="What is the title and main heading of this page? Return as JSON: {title, heading}",
    )
    return result


@app.post("/scrape-resources")
async def scrape_resources(payload: dict, authorization: str = Header(None)):
    """Scrape real resources for a task using TinyFish"""
    try:
        token = authorization.replace("Bearer ", "") if authorization else ""
        decoded = auth.verify_id_token(token)
        uid = decoded["uid"]
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token")
    topic = payload.get("topic", "")
    category = payload.get("category", "study")
    task_id = payload.get("task_id", "")
    if not topic:
        raise HTTPException(status_code=400, detail="topic required")
    result = tinyfish_service.scrape_resources(topic, category)
    if result.get("success") and task_id and uid:
        db.collection("users").document(uid).collection("tasks").document(
            task_id
        ).update(
            {
                "tinyfishResources": result.get("result", ""),
                "resourcesScraped": True,
            }
        )
    return result


@app.get("/init-notion")
async def init_notion(authorization: str = Header(None)):
    """
    Create Tasks DB in the user's Notion workspace (public OAuth integration).
    Requires Firebase auth and notionToken in Firestore — no internal NOTION_API_KEY.
    Uses NOTION_PARENT_PAGE_ID from Cloud Run as the parent page.
    """
    notion_token = None
    uid = None
    if authorization:
        try:
            token = authorization.replace("Bearer ", "")
            decoded = auth.verify_id_token(token)
            uid = decoded["uid"]
            notion_token = _get_notion_token(uid)
        except Exception as e:
            logger.warning("init_notion: auth failed: %s", e)
    bootstrap_token = (notion_token or "").strip()
    if not bootstrap_token:
        logger.warning("init_notion: user Notion OAuth token missing — connect Notion in the app")
        env_db = os.environ.get("NOTION_DATABASE_ID", "") or None
        return {
            "success": False,
            "database_id": env_db,
            "message": "Connect Notion (OAuth) first; optional NOTION_DATABASE_ID from env returned for reference.",
        }
    parent_page_id = None
    if uid:
        udata = db.collection("users").document(uid).get().to_dict() or {}
        parent_page_id = (udata.get("notionParentPageId") or "").strip() or None
    if not parent_page_id:
        parent_page_id = (os.environ.get("NOTION_PARENT_PAGE_ID") or "").strip() or None
    database_id, parent_used = notion_service.initialize_dashboard(
        notion_token=bootstrap_token,
        parent_page_id=parent_page_id,
    )
    if database_id and uid:
        upd = {"notionDatabaseId": database_id}
        udata = db.collection("users").document(uid).get().to_dict() or {}
        if parent_used and not (udata.get("notionParentPageId") or "").strip():
            upd["notionParentPageId"] = parent_used
        db.collection("users").document(uid).set(upd, merge=True)
    if database_id:
        return {"success": True, "database_id": database_id}
    return {
        "success": False,
        "database_id": os.environ.get("NOTION_DATABASE_ID"),
        "message": "Could not create database; check NOTION_PARENT_PAGE_ID and integration access.",
    }


@app.post("/generate-doc")
async def generate_doc(req: GenerateDocRequest, authorization: str = Header(None)):
    """
    Creates the category launchpad page in Notion (create_launchpad_doc).
    Uses the user's OAuth token from Firestore and NOTION_PARENT_PAGE_ID from Cloud Run.
    """
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing auth")
    try:
        token = authorization.replace("Bearer ", "")
        decoded = auth.verify_id_token(token)
        uid = decoded["uid"]
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {str(e)}")

    if req.uid and req.uid != uid:
        logger.warning("generate_doc: body uid does not match token uid")
        raise HTTPException(status_code=403, detail="uid mismatch")

    logger.info(f"📄 /generate-doc called for task: {req.taskId} user: {uid}")
    logger.info(
        f"generate-doc received: title={req.title}, category={req.category}, "
        f"schedule_len={len(req.schedule or [])}, taskId={req.taskId}"
    )

    user_doc = db.collection("users").document(uid).get()
    user_data_early = user_doc.to_dict() or {}
    notion_token = user_data_early.get("notionToken")
    if not notion_token:
        logger.warning(f"⚠️ User {uid} has not connected Notion — skipping doc generation")
        return {"success": False, "error": "Notion not connected"}

    task_ref = db.collection("users").document(uid).collection("tasks").document(req.taskId)
    task_doc = task_ref.get()
    if not task_doc.exists:
        raise HTTPException(status_code=404, detail="Task not found")

    task = task_doc.to_dict() or {}
    ai = task.get("ai") or {}
    try:
        estimated_minutes = int(ai.get("estimatedMinutes") or task.get("estimatedMinutes") or 60)
    except (TypeError, ValueError):
        estimated_minutes = 60

    # Use schedule from request; fall back to Firestore ai.schedule if empty
    schedule = req.schedule or []
    if not schedule:
        ai_data = task.get("ai") or {}
        schedule = ai_data.get("schedule", [])
        if not estimated_minutes or estimated_minutes == 60:
            estimated_minutes = int(ai_data.get("estimatedMinutes") or 60)
        logger.info(f"Fetched schedule from Firestore: {len(schedule)} days")

    user_data = db.collection("users").document(uid).get().to_dict() or {}
    parent_override = (user_data.get("notionParentPageId") or "").strip() or None

    cat_raw = (req.category or task.get("category") or "work").strip().lower()
    if cat_raw == "personal":
        cat = "Personal"
    elif cat_raw == "study":
        cat = "Study"
    else:
        cat = "Work"

    result = notion_service.create_launchpad_doc(
        title=req.title,
        deadline=req.deadline,
        estimated_minutes=estimated_minutes,
        schedule=schedule,
        category=cat,
        notion_token=str(notion_token).strip(),
        parent_page_id=parent_override,
    )
    if not result:
        raise HTTPException(status_code=502, detail="Notion launchpad creation failed")

    resolved_parent = result.get("parent_page_id")
    if resolved_parent and not parent_override:
        db.collection("users").document(uid).set(
            {"notionParentPageId": resolved_parent}, merge=True
        )

    page_id = result.get("page_id")
    page_url = result.get("page_url")
    breakdown_db_id = result.get("breakdown_db_id", "")
    if page_id or page_url:
        updates = {}
        if page_id:
            updates["notionPageId"] = page_id
            updates["notionDocPageId"] = page_id
        if page_url:
            updates["notionLaunchpadUrl"] = page_url
        if breakdown_db_id:
            updates["notionBreakdownDbId"] = breakdown_db_id
        if updates:
            task_ref.set(updates, merge=True)
            if breakdown_db_id:
                logger.info(f"✅ Saved notionBreakdownDbId: {breakdown_db_id}")
            if page_id:
                logger.info(f"✅ Saved notionDocPageId: {page_id}")
                logger.info(f"🔍 TinyFish starting (sync) for: {req.title}")
                loop = asyncio.get_event_loop()
                with concurrent.futures.ThreadPoolExecutor() as pool:
                    await loop.run_in_executor(
                        pool,
                        lambda: _scrape_and_populate_sync(
                            uid=uid,
                            task_id=req.taskId,
                            title=req.title,
                            category=cat_raw,
                            notion_page_id=page_id,
                            notion_token=str(notion_token).strip(),
                        )
                    )
                logger.info(f"🔍 TinyFish complete for: {req.title}")

    # Generate Excalidraw workflow using actual task steps
    if not schedule:
        task_doc_data = db.collection("users").document(uid).collection("tasks").document(req.taskId).get().to_dict() or {}
        schedule = task_doc_data.get("ai", {}).get("schedule", [])

    steps = list(dict.fromkeys([
        day.get("subtask", "").strip() for day in schedule
        if day.get("subtask", "").strip()
    ]))

    # Use Gemini to generate workflow steps from schedule
    if steps:
        try:
            import json as _json, re as _re_steps
            steps_prompt = f"""You are a project planning expert. For this specific task: "{req.title}"
Generate exactly 6 specific, action-oriented workflow steps.
Each step must be specific to "{req.title}" — not generic like "Research" or "Plan".
Each step maximum 4 words.
Return ONLY a valid JSON array of 6 strings.
Example for "Build a weather forecasting model":
["Collect Weather Data", "Clean & Preprocess", "Select ML Model", "Train & Validate", "Tune Parameters", "Deploy & Monitor"]
Now generate for: "{req.title}" """

            gemini_response = client.models.generate_content(
                model="gemini-2.5-flash",
                contents=steps_prompt,
            )
            raw_steps = gemini_response.text.strip()
            json_match = _re_steps.search(r'\[.*?\]', raw_steps, _re_steps.DOTALL)
            if json_match:
                ai_steps = _json.loads(json_match.group())
                steps = [str(s)[:30] for s in ai_steps if s][:7]
                logger.info(f"✅ Gemini generated steps for {req.title}: {steps}")
        except Exception as e:
            logger.warning(f"Gemini steps generation failed, using schedule steps: {e}")

    logger.info(f"Excalidraw steps for {req.title}: {steps}")

    if steps:
        import threading as _threading
        import uuid as _uuid
        import re as _re
        _job_id = str(_uuid.uuid4())[:8]
        _page_id = page_id
        _title = req.title
        _category = cat_raw
        _uid = uid
        _task_id = req.taskId
        _notion_token = str(notion_token).strip()
        _steps = steps

        def create_excalidraw():
            try:
                result = tinyfish_service.create_excalidraw_workflow(_title, _category, _steps)
                import re as _re2
                from urllib.parse import unquote as _unquote
                raw_str = str(result.get("result", ""))
                excalidraw_url = ""
                # Method 1: Extract from COMPLETE result JSON
                try:
                    import json as _json2
                    for line in raw_str.split("\n"):
                        if '"COMPLETE"' in line or '"url"' in line:
                            try:
                                data = _json2.loads(line)
                                if data.get("result", {}).get("url"):
                                    excalidraw_url = data["result"]["url"]
                                    break
                            except:
                                pass
                except:
                    pass
                # Method 2: Regex for room URL
                if not excalidraw_url:
                    room_matches = _re2.findall(r'https://excalidraw\.com/#room=[^"\s\\]+', raw_str)
                    if room_matches:
                        excalidraw_url = _unquote(room_matches[0])
                # Method 3: Regex for json URL
                if not excalidraw_url:
                    json_matches = _re2.findall(r'https://excalidraw\.com/#json=[^"\s\\]+', raw_str)
                    if json_matches:
                        excalidraw_url = _unquote(json_matches[0])
                excalidraw_url = _unquote(excalidraw_url).strip()
                logger.info(f"🎨 Extracted Excalidraw URL: {excalidraw_url}")
                if excalidraw_url:
                    logger.info(f"✅ Excalidraw URL generated: {excalidraw_url}")
                    db.collection("users").document(_uid).collection("tasks").document(_task_id).update({
                        "workflowUrl": excalidraw_url
                    })
                    logger.info(f"🎨 Updating Notion page {_page_id} with Excalidraw URL: {excalidraw_url}")
                    success = notion_service.update_workflow_link(_page_id, excalidraw_url, _notion_token)
                    logger.info(f"🎨 Notion update result: {success}")
                else:
                    logger.warning(f"⚠️ No Excalidraw URL found in result: {str(raw)[:200]}")
            except Exception as e:
                logger.error(f"❌ Excalidraw generation error: {e}")

        _threading.Thread(target=create_excalidraw, daemon=False).start()
        logger.info(f"🎨 Excalidraw generation started for: {req.title} with steps: {steps}")

    return {"success": True, "page_id": page_id, "page_url": page_url}


@app.post("/plan-task")
async def plan_task(taskId: str, authorization: str = Header(None)):
    try:
        logger.info(f"📥 Received plan-task request for taskId: {taskId}")
        
        if not authorization:
            logger.warning("❌ Missing authorization header")
            raise HTTPException(status_code=401, detail="Missing auth")

        # Verify Firebase user
        try:
            token = authorization.replace("Bearer ", "")
            decoded = auth.verify_id_token(token)
            uid = decoded["uid"]
            logger.info(f"✅ Authenticated user: {uid}")
        except Exception as e:
            logger.error(f"❌ Auth verification failed: {e}")
            raise HTTPException(status_code=401, detail=f"Invalid token: {str(e)}")

        # Fetch task - CRITICAL: Always use user's UID to scope the query
        try:
            task_ref = db.collection("users").document(uid).collection("tasks").document(taskId)
            logger.info(f"🔍 Fetching task from: users/{uid}/tasks/{taskId}")
            task_doc = task_ref.get()
            
            if not task_doc.exists:
                logger.warning(f"❌ Task not found for user {uid}: {taskId}")
                raise HTTPException(status_code=404, detail="Task not found")

            task = task_doc.to_dict()
            logger.info(f"✅ Task fetched for user {uid}: {task.get('title', 'Unknown')}")
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"❌ Failed to fetch task: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to fetch task: {str(e)}")

        description = task.get("description", "")
        title = task.get("title", "Task")
        logger.info(f"📋 Task: {title}, Description length: {len(description)}")
        logger.info(f"📋 Task fields: {list(task.keys())}")

        # Normalize category from Firestore ("work"/"study"/"personal") to
        # canonical form ("Work"/"Study"/"Personal") used in prompts and Notion.
        _cat_raw = (task.get("category") or "work").strip().lower()
        if _cat_raw == "personal":
            category = "Personal"
        elif _cat_raw == "study":
            category = "Study"
        else:
            category = "Work"
        logger.info(f"📋 Category: {category}")
        
        # Handle dueDate field (Firestore Timestamp)
        # Flutter stores it as "dueDate", not "deadline"
        due_date = task.get("dueDate") or task.get("deadline")  # Support both for compatibility
        if not due_date:
            logger.error(f"❌ Task has no dueDate or deadline. Available fields: {list(task.keys())}")
            raise HTTPException(
                status_code=400, 
                detail=f"Task missing dueDate field. Available fields: {list(task.keys())}"
            )
        
        logger.info(f"📅 Due date type: {type(due_date)}, value: {due_date}")
        
        # Convert dueDate to datetime.
        # Firestore Admin SDK returns timestamps as DatetimeWithNanoseconds (subclass of datetime).
        try:
            if isinstance(due_date, datetime):
                # Firestore already returns a datetime-like object
                deadline = due_date

                if deadline.tzinfo is None:
                    deadline = deadline.replace(tzinfo=timezone.utc)

                logger.info(f"✅ Using datetime object: {deadline}")

            elif isinstance(due_date, dict):
                # Firestore Timestamp dict format (if serialized)
                seconds = due_date.get("_seconds", 0)
                deadline = datetime.fromtimestamp(seconds, tz=timezone.utc)
                logger.info(f"✅ Converted dict to datetime: {deadline}")

            else:
                # Fallback: try to parse as unix timestamp (seconds)
                deadline = datetime.fromtimestamp(float(due_date), tz=timezone.utc)
                logger.info(f"✅ Converted float to datetime: {deadline}")

        except Exception as e:
            logger.error(f"❌ Failed to convert dueDate: {e}, type: {type(due_date)}")
            raise HTTPException(status_code=400, detail=f"Invalid dueDate format: {str(e)}")
        
        now = datetime.now(timezone.utc)
        logger.info(f"⏰ Now: {now.isoformat()}, Deadline: {deadline.isoformat()}")

        # Existing AI data (if any) – used for replanning & progress
        existing_ai = task.get("ai") or {}
        existing_schedule = existing_ai.get("schedule") or []

        estimated_minutes = None
        confidence = float(existing_ai.get("confidence", 0.0))
        
        if "estimatedMinutes" in existing_ai:
            try:
                estimated_minutes = int(existing_ai.get("estimatedMinutes") or 0)
            except Exception:
                estimated_minutes = None

        if not estimated_minutes or not existing_schedule:
            today_str = now.strftime('%Y-%m-%d')
            deadline_str = deadline.strftime('%Y-%m-%d')
            rem_days = _days_inclusive(now, deadline)

            _json_schema = """{
  "estimatedMinutes": <integer — total minutes for the full period>,
  "confidence": <float 0.0–1.0>,
  "schedule": [
    {
      "date": "YYYY-MM-DD",
      "subtask": "<label for this day's focus>",
      "microtasks": [
        {"title": "<action>", "completed": false}
      ]
    }
  ]
}"""

            if category == "Personal":
                prompt = f"""You are a personal productivity assistant helping someone build a daily habit or achieve a personal goal.

Task: {title}
Description: {description}
Start date: {today_str}
End date: {deadline_str}
Days available: {rem_days}

Rules:
- Do NOT break this into subtopics, project phases, or learning objectives.
- Allocate simple, repeating daily time blocks only.
- Each microtask = one concrete action with a time estimate (e.g. "Go to gym — 1 hr", "Read for 30 mins", "Meditate — 10 mins").
- For habits: repeat the same block every single day.
- For books or reading goals: just allocate reading time per day — no chapter breakdowns unless the description explicitly asks for them.
- Keep 1–3 microtasks per day maximum.
- subtask field = a short daily label like "Daily habit", "Morning run", or "Reading session".
- estimatedMinutes = realistic minutes per day × number of days (not just one session).

Return ONLY valid JSON — no prose, no markdown fences:
{_json_schema}"""

            elif category == "Study":
                prompt = f"""You are a study planner helping someone learn a topic or prepare for an exam.

Task: {title}
Description: {description}
Start date: {today_str}
End date: {deadline_str}
Days available: {rem_days}

Rules:
- Break the subject into 3–6 distinct subtopics.
- Assign subtopics to specific days — one subtopic per day or contiguous block of days.
- Each microtask = one subtopic to study (e.g. "Study: Newton's Laws — 45 mins", "Practice: Integration by parts — 30 mins").
- Do NOT write explanations or descriptions of what the topic is about — just what to study and for how long.
- Keep 2–4 microtasks per day.
- subtask field = the name of the subtopic being covered that day (e.g. "Kinematics", "Chapter 3 — Thermodynamics").
- estimatedMinutes = realistic total study time across the full period.

Return ONLY valid JSON — no prose, no markdown fences:
{_json_schema}"""

            else:  # Work
                prompt = f"""You are a project manager breaking down a work task into clear, actionable steps.

Task: {title}
Description: {description}
Start date: {today_str}
End date: {deadline_str}
Days available: {rem_days}

Rules:
- Break the project into clear phases (e.g. Research, Design, Implementation, Testing, Review, Deploy).
- Each phase has step-by-step, concrete microtasks focused on WHAT TO DO — not what to learn or understand.
- If a step depends on a previous one, note it in the title (e.g. "Write API routes (after: DB schema done)").
- Think like a project manager: deliverables, not learning objectives.
- Keep 3–5 microtasks per day.
- subtask field = the phase name (e.g. "Research phase", "Implementation phase").
- estimatedMinutes = realistic total work time for the full project.

Return ONLY valid JSON — no prose, no markdown fences:
{_json_schema}"""

            logger.info(f"🤖 Using {category} prompt ({rem_days} days, deadline={deadline_str})")

            # Call Gemini
            try:
                logger.info("🤖 Calling Gemini AI to estimate and decompose task...")
                response = client.models.generate_content(
                    model="gemini-2.5-flash",
                    contents=prompt,
                )
                response_text = (response.text or "").strip()
                # Bug 2 fix: log the full raw response so we can see exactly what Gemini returned
                logger.info(f"📥 Raw Gemini response ({len(response_text)} chars):\n{response_text[:2000]}")

                if response_text.startswith("```json"):
                    response_text = response_text[7:]
                if response_text.startswith("```"):
                    response_text = response_text[3:]
                if response_text.endswith("```"):
                    response_text = response_text[:-3]
                response_text = response_text.strip()

                ai_raw = json.loads(response_text)

                # Bug 2 fix: .get("estimatedMinutes", 60) only uses the default when the KEY
                # is absent. If Gemini returns "estimatedMinutes": null the key IS present but
                # the value is None, so int(None) would throw TypeError and abort the whole
                # request before Firestore is written. Explicitly guard against None/non-numeric.
                raw_em = ai_raw.get("estimatedMinutes")
                logger.info(f"📊 Gemini estimatedMinutes raw value: {raw_em!r} (type: {type(raw_em).__name__})")
                try:
                    estimated_minutes = int(raw_em) if raw_em is not None else 60
                except (TypeError, ValueError):
                    logger.warning(f"⚠️ Could not parse estimatedMinutes={raw_em!r}, defaulting to 60")
                    estimated_minutes = 60

                confidence = float(ai_raw.get("confidence") or 0.7)
                schedule = ai_raw.get("schedule") or []
                logger.info(f"📊 Parsed from Gemini — estimatedMinutes={estimated_minutes}, confidence={confidence}, schedule_days={len(schedule)}")
            except Exception as e:
                logger.error(f"❌ Gemini API error/parse failure: {e}")
                # Log parsing failure text for debugging
                try: 
                    logger.error(f"Response text: {response_text[:500]}")
                except: 
                    pass
                raise HTTPException(status_code=500, detail=f"AI generation failed: {str(e)}")

        else:
            logger.info("ℹ️ Re-using existing AI schedule; no new Gemini call.")
            schedule = existing_schedule

        # Schedule / reschedule carryovers
        schedule = _redistribute_schedule(schedule, now, deadline)

        # Compute remaining time & pressure/risk metrics based on current progress
        metrics = _compute_time_metrics(
            estimated_minutes=estimated_minutes,
            schedule=schedule,
            now=now,
            deadline=deadline,
        )

        # Bug 1 fix: log the exact payload before writing so we can verify
        # the schedule is non-empty and estimatedMinutes is a real value.
        logger.info(f"💾 Pre-write check — estimatedMinutes={estimated_minutes}, schedule_days={len(schedule)}")
        if schedule:
            logger.info(f"💾 First schedule day: {schedule[0]}")
            if len(schedule) > 1:
                logger.info(f"💾 Last schedule day: {schedule[-1]}")
        else:
            logger.warning("⚠️ schedule is EMPTY — ai.schedule will be written as [] to Firestore")

        try:
            logger.info(f"💾 Writing AI planning data to Firestore for user: {uid}")
            task_ref.update({
                "ai": {
                    "estimatedMinutes": estimated_minutes,
                    "remainingMinutes": metrics["remainingMinutes"],
                    "dailyRequiredMinutes": metrics["dailyRequiredMinutes"],
                    "pressureScore": metrics["pressureScore"],
                    "riskScore": metrics["riskScore"],
                    "confidence": confidence,
                    "schedule": schedule,
                    "category": category,
                    "generated": True,
                    "lastPlannedAt": firestore.SERVER_TIMESTAMP
                }
            })
            logger.info(f"✅ Successfully updated Firestore")
            ai_plan_text = _generate_ai_plan_text(schedule)
            existing_notion_id = task.get("notionPageId")

            # Get user's Notion token and database ID
            user_doc = db.collection("users").document(uid).get()
            user_data = user_doc.to_dict() or {}
            _raw_token = user_data.get("notionToken")
            notion_token = str(_raw_token).strip() if _raw_token else ""
            notion_db_id = (user_data.get("notionDatabaseId") or "").strip()

            if notion_token:
                # Always try to create a new database if ID is missing
                if not notion_db_id:
                    logger.info(f"No database ID for user {uid} — searching workspace first")
                    user_parent = (user_data.get("notionParentPageId") or "").strip() or None
                    # Search for existing database before creating
                    search_response = requests.post(
                        "https://api.notion.com/v1/search",
                        headers={
                            "Authorization": f"Bearer {notion_token}",
                            "Notion-Version": "2022-06-28",
                            "Content-Type": "application/json",
                        },
                        json={"query": "DueIt Tasks", "filter": {"value": "database", "property": "object"}},
                        timeout=10,
                    )
                    if search_response.status_code == 200:
                        results = search_response.json().get("results", [])
                        if results:
                            existing_db_id = results[0]["id"]
                            db.collection("users").document(uid).set({"notionDatabaseId": existing_db_id}, merge=True)
                            notion_db_id = existing_db_id
                            logger.info(f"✅ Found existing database: {existing_db_id}")
                        else:
                            # Only create if truly doesn't exist
                            notion_db_id, parent_used = notion_service.initialize_dashboard(
                                notion_token,
                                parent_page_id=user_parent,
                            )
                            if notion_db_id:
                                upd = {"notionDatabaseId": notion_db_id}
                                if parent_used and not (user_data.get("notionParentPageId") or "").strip():
                                    upd["notionParentPageId"] = parent_used
                                db.collection("users").document(uid).set(upd, merge=True)
                                logger.info(f"✅ Created new database: {notion_db_id}")
                            else:
                                logger.warning("Failed to create Notion database")
                    else:
                        logger.warning(f"Notion search failed: {search_response.status_code} — falling back to create")
                        notion_db_id, parent_used = notion_service.initialize_dashboard(
                            notion_token,
                            parent_page_id=user_parent,
                        )
                        if notion_db_id:
                            upd = {"notionDatabaseId": notion_db_id}
                            if parent_used and not (user_data.get("notionParentPageId") or "").strip():
                                upd["notionParentPageId"] = parent_used
                            db.collection("users").document(uid).set(upd, merge=True)
                            logger.info(f"✅ Created new database: {notion_db_id}")
                        else:
                            logger.warning("Failed to create Notion database")

                if notion_db_id:
                    notion_page_id = notion_service.sync_task(
                        database_id=notion_db_id,
                        title=title,
                        deadline=deadline.strftime("%Y-%m-%d"),
                        estimated_minutes=estimated_minutes,
                        priority=task.get("priority", 2),
                        schedule=schedule,
                        ai_plan=ai_plan_text,
                        created_at=now.strftime("%Y-%m-%d"),
                        existing_page_id=existing_notion_id,
                        notion_token=notion_token,
                    )
                    if notion_page_id:
                        logger.info(f"✅ Synced to Notion: {notion_page_id}")
                        task_ref.update({"notionPageId": notion_page_id})
                    else:
                        logger.warning(
                            "⚠️ Notion sync failed — trying to recreate database"
                        )
                        # Database might be deleted — clear ID and let next request recreate it
                        db.collection("users").document(uid).set(
                            {"notionDatabaseId": ""}, merge=True
                        )
                else:
                    logger.warning("⚠️ No Notion database ID available")
            else:
                logger.info("ℹ️ User has not connected Notion — skipping sync")
        except Exception as e:
            logger.error(f"❌ Firestore update failed: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to update Firestore: {str(e)}")

        logger.info(f"✅ Task planning completed for {taskId}")
        return {
            "task_title": title,
            "deadline": deadline.isoformat(),
            "schedule": schedule
        }
    
    except HTTPException:
        raise
    except Exception as e:
        import traceback
        error_details = traceback.format_exc()
        logger.error(f"❌ Unexpected error: {error_details}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


# ── Notion OAuth endpoints ────────────────────────────────────────────────── #

@app.get("/notion-auth-url")
async def notion_auth_url(uid: str = Query(...)):
    """Returns the Notion OAuth authorization URL for the given user."""
    client_id = os.environ.get("NOTION_OAUTH_CLIENT_ID", "")
    redirect_uri = os.environ.get("NOTION_REDIRECT_URI", "")
    auth_url = (
        f"https://api.notion.com/v1/oauth/authorize"
        f"?client_id={client_id}"
        f"&response_type=code"
        f"&owner=user"
        f"&redirect_uri={redirect_uri}"
        f"&state={uid}"
    )
    return {"auth_url": auth_url}


@app.get("/notion-callback")
async def notion_callback(code: str = Query(...), state: str = Query("")):
    """
    Notion OAuth redirect handler.
    Exchanges the authorization code for an access token and saves it to Firestore.
    """
    uid = state
    client_id = os.environ.get("NOTION_OAUTH_CLIENT_ID", "")
    client_secret = os.environ.get("NOTION_OAUTH_CLIENT_SECRET", "")
    redirect_uri = os.environ.get("NOTION_REDIRECT_URI", "")

    credentials = base64.b64encode(f"{client_id}:{client_secret}".encode()).decode()

    try:
        resp = requests.post(
            "https://api.notion.com/v1/oauth/token",
            headers={
                "Authorization": f"Basic {credentials}",
                "Content-Type": "application/json",
            },
            json={
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": redirect_uri,
            },
            timeout=30,
        )
        if resp.status_code >= 400:
            logger.error(f"notion-callback: token exchange failed {resp.status_code}: {resp.text}")
            return HTMLResponse(
                "<h2>&#x274C; Connection failed. Please try again.</h2>",
                status_code=400,
            )

        data = resp.json()
        logger.info(f"notion-callback: full response from Notion: {data}")
        access_token = data.get("access_token")
        workspace_name = data.get("workspace_name", "")

        if not access_token:
            logger.error(f"notion-callback: no access_token in response: {data}")
            return HTMLResponse(
                "<h2>&#x274C; Connection failed. No token received.</h2>",
                status_code=400,
            )

        if uid:
            db.collection("users").document(uid).set(
                {
                    "notionToken": access_token,
                    "notionWorkspace": workspace_name,
                    "notionConnected": True,
                },
                merge=True,
            )
            logger.info(
                f"notion-callback: saved token starts with: {access_token[:20] if access_token else 'NONE'}"
            )
            logger.info(f"✅ notion-callback: saved token for user {uid}, workspace={workspace_name}")

        return HTMLResponse(f"""<!DOCTYPE html>
<html>
<head><title>DueIt — Notion Connected</title></head>
<body style="font-family:sans-serif;text-align:center;padding:48px;">
  <h2>&#x2705; Connected successfully!</h2>
  <p>Your Notion workspace <strong>{workspace_name}</strong> is now connected.</p>
  <p>Return to the DueIt app.</p>
</body>
</html>""")

    except Exception as e:
        logger.error(f"notion-callback error: {e}")
        return HTMLResponse(
            "<h2>&#x274C; Connection failed. Please try again.</h2>",
            status_code=500,
        )


@app.delete("/disconnect-notion")
async def disconnect_notion(body: DisconnectNotionRequest):
    """Removes the user's Notion token from Firestore and sets notionConnected = false."""
    uid = body.uid.strip()
    if not uid:
        return {"success": False, "error": "uid is required"}
    try:
        db.collection("users").document(uid).update({
            "notionToken": firestore.DELETE_FIELD,
            "notionConnected": False,
        })
        logger.info(f"✅ disconnect-notion: disconnected Notion for user {uid}")
        return {"success": True}
    except Exception as e:
        logger.error(f"disconnect-notion error: {e}")
        return {"success": False, "error": str(e)}


@app.post("/sync-task-complete")
async def sync_task_complete(taskId: str, authorization: str = Header(None)):
    """
    Marks a task as Completed in Notion.
    Called by Flutter when a task is toggled complete.
    """
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing auth")
    try:
        token = authorization.replace("Bearer ", "")
        decoded = auth.verify_id_token(token)
        uid = decoded["uid"]
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {str(e)}")

    notion_token = _get_notion_token(uid)
    if not notion_token:
        return {"success": False, "error": "Notion not connected"}

    try:
        task_ref = db.collection("users").document(uid).collection("tasks").document(taskId)
        task_doc = task_ref.get()
        if not task_doc.exists:
            raise HTTPException(status_code=404, detail="Task not found")
        task = task_doc.to_dict()
        notion_page_id = task.get("notionPageId")
        if not notion_page_id:
            return {"success": False, "error": "Task not yet synced to Notion"}

        completed = task.get("completed", False)
        new_status = "Completed" if completed else "Pending"
        ok = notion_service.update_task_status(notion_page_id, new_status, notion_token=notion_token)
        if ok:
            logger.info(f"✅ sync-task-complete: {taskId} → {new_status}")
            return {"success": True, "status": new_status}
        return {"success": False, "error": "Notion update failed"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"sync-task-complete error: {e}")
        return {"success": False, "error": str(e)}


@app.get("/test-excalidraw")
async def test_excalidraw():
    import threading, uuid
    job_id = str(uuid.uuid4())[:8]

    # Fetch the most recent task across all users to get real steps
    title = "Build a Flutter App"
    category = "work"
    steps = []
    try:
        users_snap = db.collection("users").limit(10).get()
        latest_task_data = None
        latest_created_at = None
        for user_doc in users_snap:
            tasks_snap = (
                db.collection("users").document(user_doc.id)
                .collection("tasks")
                .order_by("createdAt", direction="DESCENDING")
                .limit(1)
                .get()
            )
            for task_doc in tasks_snap:
                task_data = task_doc.to_dict() or {}
                created_at = task_data.get("createdAt")
                if latest_created_at is None or (created_at and created_at > latest_created_at):
                    latest_created_at = created_at
                    latest_task_data = task_data
        if latest_task_data:
            title = latest_task_data.get("title", title)
            category = latest_task_data.get("category", category) or category
            schedule = latest_task_data.get("ai", {}).get("schedule", [])
            steps = list(dict.fromkeys([
                day.get("subtask", "") for day in schedule if day.get("subtask")
            ]))
            logger.info(f"test-excalidraw: using real task '{title}' with {len(steps)} steps")
    except Exception as e:
        logger.warning(f"test-excalidraw: could not fetch real task, using defaults: {e}")

    if not steps:
        steps = ["Research", "Design UI", "Build Backend", "Test", "Deploy"]

    def run_job():
        result = tinyfish_service.create_excalidraw_workflow(
            title=title,
            category=category,
            steps=steps
        )
        import re, json
        from urllib.parse import unquote
        raw_str = str(result.get("result", ""))
        excalidraw_url = ""
        # Method 1: Extract from COMPLETE result JSON
        try:
            for line in raw_str.split("\n"):
                if '"COMPLETE"' in line or '"url"' in line:
                    try:
                        data = json.loads(line)
                        if data.get("result", {}).get("url"):
                            excalidraw_url = data["result"]["url"]
                            break
                    except:
                        pass
        except:
            pass
        # Method 2: Regex for room URL
        if not excalidraw_url:
            room_matches = re.findall(r'https://excalidraw\.com/#room=[^"\s\\]+', raw_str)
            if room_matches:
                excalidraw_url = unquote(room_matches[0])
        # Method 3: Regex for json URL
        if not excalidraw_url:
            json_matches = re.findall(r'https://excalidraw\.com/#json=[^"\s\\]+', raw_str)
            if json_matches:
                excalidraw_url = unquote(json_matches[0])
        excalidraw_url = unquote(excalidraw_url).strip()
        logger.info(f"🎨 Extracted Excalidraw URL: {excalidraw_url}")
        logger.info(f"test-excalidraw result: {result}")
        db.collection("tinyfish_tests").document(job_id).set({
            "result": str(result),
            "excalidraw_url": excalidraw_url,
            "done": True
        })

    threading.Thread(target=run_job, daemon=False).start()
    return {"status": "started", "job_id": job_id, "check_url": f"/test-excalidraw-result/{job_id}"}


@app.get("/test-excalidraw-result/{job_id}")
async def test_excalidraw_result(job_id: str):
    doc = db.collection("tinyfish_tests").document(job_id).get()
    if not doc.exists:
        return {"status": "running", "message": "TinyFish is creating diagram..."}
    return {"status": "done", "result": doc.to_dict()}


@app.get("/test-excalidraw-task")
async def test_excalidraw_task():
    import threading, uuid, json, re
    job_id = str(uuid.uuid4())[:8]
    title = "Build a Robotic Arm"
    category = "work"

    # Generate steps using Gemini
    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=f'Generate 6 specific workflow steps for "{title}". Return ONLY a JSON array of short strings (2-4 words each).',
        )
        match = re.search(r'\[.*?\]', response.text, re.DOTALL)
        steps = json.loads(match.group()) if match else ["Research", "Design", "Build", "Test", "Deploy"]
    except Exception:
        steps = ["Research", "Design", "Build", "Test", "Deploy"]

    def run_job():
        result = tinyfish_service.create_excalidraw_workflow(title, category, steps)
        import re, json
        from urllib.parse import unquote
        raw_str = str(result.get("result", ""))
        excalidraw_url = ""
        # Method 1: Extract from COMPLETE result JSON
        try:
            for line in raw_str.split("\n"):
                if '"COMPLETE"' in line or '"url"' in line:
                    try:
                        data = json.loads(line)
                        if data.get("result", {}).get("url"):
                            excalidraw_url = data["result"]["url"]
                            break
                    except:
                        pass
        except:
            pass
        # Method 2: Regex for room URL
        if not excalidraw_url:
            room_matches = re.findall(r'https://excalidraw\.com/#room=[^"\s\\]+', raw_str)
            if room_matches:
                excalidraw_url = unquote(room_matches[0])
        # Method 3: Regex for json URL
        if not excalidraw_url:
            json_matches = re.findall(r'https://excalidraw\.com/#json=[^"\s\\]+', raw_str)
            if json_matches:
                excalidraw_url = unquote(json_matches[0])
        excalidraw_url = unquote(excalidraw_url).strip()
        logger.info(f"🎨 Extracted Excalidraw URL: {excalidraw_url}")
        logger.info(f"test-excalidraw-task result: {result}")
        db.collection("tinyfish_tests").document(job_id).set({
            "result": str(result), "excalidraw_url": excalidraw_url, "done": True, "steps_used": steps
        })

    threading.Thread(target=run_job, daemon=False).start()
    return {"status": "started", "job_id": job_id, "steps_being_used": steps, "check_url": f"/test-excalidraw-result/{job_id}"}


@app.post("/create-excalidraw-workflow")
async def create_excalidraw_workflow_endpoint(payload: dict, authorization: str = Header(None)):
    try:
        token = authorization.replace("Bearer ", "") if authorization else ""
        decoded = auth.verify_id_token(token)
        uid = decoded["uid"]
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token")

    title = payload.get("title", "")
    category = payload.get("category", "work")
    task_id = payload.get("task_id", "")
    import threading, uuid
    job_id = str(uuid.uuid4())[:8]

    steps = []
    if task_id and uid:
        task_doc = db.collection("users").document(uid).collection("tasks").document(task_id).get()
        task_data = task_doc.to_dict() or {}
        schedule = task_data.get("ai", {}).get("schedule", [])
        steps = list(dict.fromkeys([
            day.get("subtask", "") for day in schedule if day.get("subtask")
        ]))
    if not steps:
        steps = ["Research", "Plan", "Execute", "Review", "Deliver"]

    def run_job():
        result = tinyfish_service.create_excalidraw_workflow(title, category, steps)
        raw = result.get("result", "").strip()
        excalidraw_url = ""
        for line in raw.split("\n"):
            if "excalidraw.com" in line:
                excalidraw_url = line.strip()
                break
        if not excalidraw_url and "excalidraw" in raw:
            excalidraw_url = raw
        if excalidraw_url.startswith("http") and task_id and uid:
            db.collection("users").document(uid).collection("tasks").document(task_id).update({
                "workflowUrl": excalidraw_url
            })
            task_doc = db.collection("users").document(uid).collection("tasks").document(task_id).get()
            notion_doc_page_id = (task_doc.to_dict() or {}).get("notionDocPageId")
            notion_token = (db.collection("users").document(uid).get().to_dict() or {}).get("notionToken")
            if notion_doc_page_id and notion_token:
                notion_service.update_workflow_link(notion_doc_page_id, excalidraw_url, notion_token)
        db.collection("tinyfish_tests").document(job_id).set({
            "excalidraw_url": excalidraw_url,
            "done": True
        })
        logger.info(f"✅ Excalidraw workflow created: {excalidraw_url}")

    threading.Thread(target=run_job, daemon=False).start()
    return {"status": "started", "job_id": job_id, "message": "Workflow diagram being created..."}
