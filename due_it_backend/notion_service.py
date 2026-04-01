"""
Notion API integration for Due It backend.
Uses Notion API version 2022-06-28. Failures return None / False without raising.
"""

from __future__ import annotations

import logging
import os
from datetime import datetime, timezone
from typing import Any, List, Optional, Tuple, Union

import requests

logger = logging.getLogger(__name__)

NOTION_VERSION = "2022-06-28"
NOTION_BASE = "https://api.notion.com/v1"


def _headers(token: Optional[str] = None) -> Optional[dict]:
    """
    Build Notion API headers. Requires an explicit OAuth/integration token.
    Does NOT fall back to NOTION_API_KEY — callers must pass the token they intend to use.
    """
    if not token or not str(token).strip():
        logger.warning("Notion API: no token provided (refusing env fallback)")
        return None
    return {
        "Authorization": f"Bearer {str(token).strip()}",
        "Notion-Version": NOTION_VERSION,
        "Content-Type": "application/json",
    }


def _rich_text(content: str) -> List[dict]:
    return [
        {
            "type": "text",
            "text": {"content": content[:2000]},
        }
    ]


def _normalize_priority(priority: Union[int, str, float, None]) -> int:
    """Map priority to 1–3 for the Tasks database (number property)."""
    if priority is None:
        return 2
    if isinstance(priority, (int, float)):
        p = int(priority)
        if 1 <= p <= 3:
            return p
        return 2 if p < 1 else 3
    if isinstance(priority, str):
        m = {"high": 3, "medium": 2, "low": 1}
        return m.get(priority.strip().lower(), 2)
    return 2


# ── Convenience block builders ────────────────────────────────────────────── #

def _h2(text: str) -> dict:
    return {"object": "block", "type": "heading_2",
            "heading_2": {"rich_text": _rich_text(text)}}


def _paragraph(text: str) -> dict:
    return {"object": "block", "type": "paragraph",
            "paragraph": {"rich_text": _rich_text(text) if text else []}}


def _divider() -> dict:
    return {"object": "block", "type": "divider", "divider": {}}


def _bullet(text: str) -> dict:
    return {"object": "block", "type": "bulleted_list_item",
            "bulleted_list_item": {"rich_text": _rich_text(text)}}


def _todo(text: str, checked: bool = False) -> dict:
    return {"object": "block", "type": "to_do",
            "to_do": {"rich_text": _rich_text(text), "checked": checked}}


def _table_block(rows: List[List[str]]) -> dict:
    """
    Builds a Notion table block.  First row is treated as the column header.
    Each inner list is a row; each string is a cell value.
    """
    if not rows:
        return _paragraph("(no rows)")
    width = max(len(r) for r in rows)

    def _cell(text: str) -> List[dict]:
        return [{"type": "text", "text": {"content": text[:2000]}}]

    table_rows = []
    for r in rows:
        cells = [_cell(r[i] if i < len(r) else "") for i in range(width)]
        table_rows.append({
            "object": "block",
            "type": "table_row",
            "table_row": {"cells": cells},
        })

    return {
        "object": "block",
        "type": "table",
        "table": {
            "table_width": width,
            "has_column_header": True,
            "has_row_header": False,
        },
        "children": table_rows,
    }


def _search_first_accessible_page_id(notion_token: Optional[str]) -> Optional[str]:
    """
    Returns the first page id the integration can access (POST /search).
    Used when NOTION_PARENT_PAGE_ID points to a deleted or unshared page (404).
    """
    hdrs = _headers(notion_token)
    if not hdrs:
        return None
    try:
        r = requests.post(
            f"{NOTION_BASE}/search",
            headers=hdrs,
            json={
                "filter": {"value": "page", "property": "object"},
                "page_size": 10,
            },
            timeout=60,
        )
        if r.status_code >= 400:
            logger.warning(
                "Notion search (fallback parent) failed: %s %s",
                r.status_code,
                r.text,
            )
            return None
        data = r.json()
        for item in data.get("results") or []:
            if item.get("object") == "page":
                pid = item.get("id")
                if pid:
                    return pid
        return None
    except Exception as e:
        logger.warning("Notion search error: %s", e)
        return None


def initialize_dashboard(
    notion_token: str = None,
    parent_page_id: Optional[str] = None,
) -> Tuple[Optional[str], Optional[str]]:
    """
    Creates a "Tasks" database under the given parent page (user Firestore field,
    then NOTION_PARENT_PAGE_ID env).

    If the parent returns 404 (deleted / not shared with the integration), retries once
    using the first accessible page from Notion search.

    Returns (database_id, parent_page_id_used) or (None, None) on failure.
    """
    parent_id = (parent_page_id or "").strip() or (
        os.environ.get("NOTION_PARENT_PAGE_ID") or ""
    ).strip()
    if not parent_id:
        logger.warning("NOTION_PARENT_PAGE_ID is not set and no parent_page_id passed")
        return None, None

    hdrs = _headers(notion_token)
    if not hdrs:
        logger.warning("initialize_dashboard: missing Notion token")
        return None, None

    def _payload(pid: str) -> dict:
        return {
            "parent": {"type": "page_id", "page_id": pid.strip()},
            "title": _rich_text("Tasks"),
            "properties": {
                "Name": {"title": {}},
                "Deadline": {"date": {}},
                "Status": {
                    "select": {
                        "options": [
                            {"name": "Pending", "color": "gray"},
                            {"name": "Completed", "color": "green"},
                        ]
                    }
                },
                "Priority": {"number": {"format": "number"}},
                "Duration": {"number": {"format": "number"}},
                "AI Plan": {"rich_text": {}},
                "Created At": {"date": {}},
            },
        }

    try:
        used_parent = parent_id
        r = requests.post(
            f"{NOTION_BASE}/databases",
            headers=hdrs,
            json=_payload(used_parent),
            timeout=60,
        )
        if r.status_code == 404:
            fallback = _search_first_accessible_page_id(notion_token)
            if fallback and fallback != used_parent:
                logger.warning(
                    "initialize_dashboard: parent page not accessible (404); "
                    "retrying under first page from workspace search. "
                    "Update NOTION_PARENT_PAGE_ID in Cloud Run or set notionParentPageId "
                    "on users/{uid} to a page shared with the DueIt integration."
                )
                used_parent = fallback
                r = requests.post(
                    f"{NOTION_BASE}/databases",
                    headers=hdrs,
                    json=_payload(used_parent),
                    timeout=60,
                )
        if r.status_code >= 400:
            logger.warning("Notion create database failed: %s %s", r.status_code, r.text)
            return None, None
        data = r.json()
        db_id = data.get("id")
        if not db_id:
            logger.warning("Notion response missing database id: %s", data)
            return None, None
        return db_id, used_parent
    except Exception as e:
        logger.warning("Notion initialize_dashboard error: %s", e)
        return None, None


def ensure_user_database(
    uid: str,
    notion_token: str,
    parent_page_id: str,
) -> Optional[str]:
    """
    Return the user's Tasks database ID from Firestore (notionDatabaseId).
    If missing, create a database in their workspace with initialize_dashboard,
    save notionDatabaseId on users/{uid}, and return the new id.
    """
    from firebase_admin import firestore

    db = firestore.client()
    user_ref = db.collection("users").document(uid)
    snap = user_ref.get()
    data = snap.to_dict() or {}
    existing = (data.get("notionDatabaseId") or "").strip()
    if existing:
        hdrs = _headers(notion_token)
        if hdrs:
            try:
                r = requests.get(
                    f"{NOTION_BASE}/databases/{existing}",
                    headers=hdrs,
                    timeout=30,
                )
                if r.status_code == 200:
                    return existing
                elif r.status_code == 404:
                    logger.warning(
                        "ensure_user_database: notionDatabaseId %s returned 404, will recreate",
                        existing,
                    )
                    user_ref.set({"notionDatabaseId": ""}, merge=True)
                    existing = ""
                else:
                    logger.warning(
                        "ensure_user_database: validation request returned %s, keeping existing id",
                        r.status_code,
                    )
                    return existing
            except Exception as e:
                logger.warning("ensure_user_database: error validating notionDatabaseId: %s", e)
                return existing
        else:
            return existing

    # Public integration: use Tasks database ID from Cloud Run when configured.
    env_db = (os.environ.get("NOTION_DATABASE_ID") or "").strip()
    if env_db:
        user_ref.set({"notionDatabaseId": env_db}, merge=True)
        logger.info("ensure_user_database: using NOTION_DATABASE_ID from env for uid=%s", uid)
        return env_db

    parent_user = (data.get("notionParentPageId") or "").strip()
    parent = (
        parent_user
        or (parent_page_id or "").strip()
        or os.environ.get("NOTION_PARENT_PAGE_ID", "")
    )
    if not parent:
        logger.warning("ensure_user_database: no parent page id for uid=%s", uid)
        return None

    db_id, parent_used = initialize_dashboard(
        notion_token=notion_token,
        parent_page_id=parent,
    )
    if db_id:
        updates: dict = {"notionDatabaseId": db_id}
        if parent_used and not parent_user:
            updates["notionParentPageId"] = parent_used
        user_ref.set(updates, merge=True)
        logger.info("ensure_user_database: saved notionDatabaseId for uid=%s", uid)
    return db_id


def sync_task(
    database_id: str,
    title: str,
    deadline: str,
    estimated_minutes: int,
    priority: Union[int, str, float, None] = 2,
    schedule: list = None,
    ai_plan: str = "",
    created_at: str = None,
    existing_page_id: str = None,
    notion_token: str = None,
    status: str = "Pending",
) -> Optional[str]:
    """
    Creates or updates a row in the Tasks database with body: Daily Breakdown + Notes.
    If existing_page_id is provided, patches that page (no children update).
    Returns page id or None.
    """
    if not database_id or not database_id.strip():
        logger.warning("sync_task: empty database_id")
        return None

    hdrs = _headers(notion_token)
    if not hdrs:
        logger.warning("sync_task: missing Notion token")
        return None

    try:
        em = int(estimated_minutes) if estimated_minutes is not None else 0
    except (TypeError, ValueError):
        em = 0

    # Properties must match initialize_dashboard(): Name, Deadline, Status, Priority (number),
    # Duration (minutes), AI Plan (rich_text), Created At (date).
    prio_num = _normalize_priority(priority)
    allowed_status = {"Pending", "Completed"}
    st = status if status in allowed_status else "Pending"
    created = created_at or datetime.now(timezone.utc).strftime("%Y-%m-%d")

    properties: dict[str, Any] = {
        "title": {"title": _rich_text(title)},
        "Deadline": {"date": {"start": deadline}},
        "Status": {"select": {"name": st}},
        "Priority": {"number": prio_num},
        "Duration": {"number": float(em)},
        "AI Plan": {"rich_text": _rich_text(ai_plan or "")},
        "Created At": {"date": {"start": created}},
    }

    # ── UPDATE existing page ──────────────────────────────────────────── #
    if existing_page_id:
        try:
            body = {"properties": properties}
            r = requests.patch(
                f"{NOTION_BASE}/pages/{existing_page_id}",
                headers=hdrs,
                json=body,
                timeout=60,
            )
            if r.status_code >= 400:
                logger.warning("Notion patch page failed: %s %s", r.status_code, r.text)
                return None
            return existing_page_id
        except Exception as e:
            logger.warning("Notion sync_task patch error: %s", e)
            return None

    # ── CREATE new page ───────────────────────────────────────────────── #

    children: List[dict] = [
        {
            "object": "block",
            "type": "heading_1",
            "heading_1": {"rich_text": _rich_text("Daily Breakdown")},
        }
    ]

    try:
        for day in schedule or []:
            if not isinstance(day, dict):
                continue
            d = day.get("date", "")
            sub = day.get("subtask", "") or ""
            mts = day.get("microtasks") or []
            n = len(mts) if isinstance(mts, list) else 0
            line = f"Day {d} — {sub} — [{n} microtasks]"
            children.append(
                {
                    "object": "block",
                    "type": "to_do",
                    "to_do": {
                        "rich_text": _rich_text(line),
                        "checked": False,
                    },
                }
            )

        children.append({"object": "block", "type": "divider", "divider": {}})

        children.append(
            {
                "object": "block",
                "type": "heading_1",
                "heading_1": {"rich_text": _rich_text("Notes")},
            }
        )
        children.append(
            {
                "object": "block",
                "type": "paragraph",
                "paragraph": {"rich_text": []},
            }
        )

        body = {
            "parent": {"database_id": database_id.strip()},
            "properties": properties,
            "children": children[:100],
        }

        r = requests.post(f"{NOTION_BASE}/pages", headers=hdrs, json=body, timeout=60)
        if r.status_code >= 400:
            logger.warning("Notion create page failed: %s %s", r.status_code, r.text)
            return None
        data = r.json()
        page_id = data.get("id")
        return page_id
    except Exception as e:
        logger.warning("Notion sync_task error: %s", e)
        return None


def update_workflow_link(page_id: str, workflow_url: str, notion_token: str = None) -> bool:
    """Replace the workflow placeholder paragraph with the actual Excalidraw callout."""
    hdrs = _headers(notion_token)
    if not hdrs or not page_id:
        return False
    try:
        # Fetch all blocks
        r = requests.get(
            f"{NOTION_BASE}/blocks/{page_id}/children",
            headers=hdrs, timeout=30
        )
        if r.status_code >= 400:
            return False

        blocks = r.json().get("results", [])

        # Find workflow heading block id and placeholder block id
        workflow_heading_id = None
        placeholder_id = None
        for block in blocks:
            if block.get("type") == "heading_2":
                text = block.get("heading_2", {}).get("rich_text", [])
                if text and "Workflow" in text[0].get("text", {}).get("content", ""):
                    workflow_heading_id = block["id"]
            if block.get("type") == "paragraph":
                text = block.get("paragraph", {}).get("rich_text", [])
                if text and "Generating" in text[0].get("text", {}).get("content", ""):
                    placeholder_id = block["id"]

        # Delete placeholder
        if placeholder_id:
            requests.delete(
                f"{NOTION_BASE}/blocks/{placeholder_id}",
                headers=hdrs, timeout=30
            )
            logger.info(f"🗑️ Deleted workflow placeholder block")

        # Build callout block
        new_block = {
            "object": "block",
            "type": "callout",
            "callout": {
                "rich_text": [
                    {"type": "text", "text": {"content": "Your workflow diagram is ready → "}},
                    {
                        "type": "text",
                        "text": {
                            "content": "Open Excalidraw Workflow",
                            "link": {"url": workflow_url}
                        },
                        "annotations": {"bold": True, "color": "blue"}
                    }
                ],
                "icon": {"type": "emoji", "emoji": "🎨"}
            }
        }

        # Append callout after workflow heading so it appears in the right position
        patch_payload: dict = {"children": [new_block]}
        if workflow_heading_id:
            patch_payload["after"] = workflow_heading_id

        r2 = requests.patch(
            f"{NOTION_BASE}/blocks/{page_id}/children",
            headers=hdrs,
            json=patch_payload,
            timeout=30
        )
        success = r2.status_code < 400
        logger.info(f"✅ Workflow link updated in Notion: {success}")
        return success
    except Exception as e:
        logger.warning(f"update_workflow_link error: {e}")
        return False


def add_resources_to_page(
    page_id: str,
    notion_token: str,
    resources_text: str,
) -> bool:
    """
    Replace the 'Finding resources...' placeholder with clean hyperlink bullets.
    Fetches page blocks, deletes the placeholder paragraph, then inserts bullets
    right after the Resources heading using the Notion API 'after' parameter.
    """
    if not page_id or not resources_text or not str(resources_text).strip():
        return False
    hdrs = _headers(notion_token)
    if not hdrs:
        return False
    logger.info(f"🎯 Target page for resources: {page_id}")

    # Accept a pre-parsed list or a raw JSON string
    if isinstance(resources_text, list):
        resources = resources_text
    else:
        import json as _json
        try:
            text = str(resources_text).strip()
            if text.startswith("```"):
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]
                text = text.strip()
            resources = _json.loads(text)
            if not isinstance(resources, list):
                resources = []
        except Exception:
            logger.warning("add_resources_to_page: could not parse resources JSON")
            resources = []

    if not resources:
        logger.warning("add_resources_to_page: no valid resources to add")
        return False

    logger.info(f"🔗 Replacing placeholder with {len(resources)} resources")

    # ── Fetch page blocks to find heading and placeholder ─────────────── #
    resources_heading_id: Optional[str] = None
    placeholder_id: Optional[str] = None
    try:
        r = requests.get(
            f"{NOTION_BASE}/blocks/{page_id}/children",
            headers=hdrs,
            timeout=60,
        )
        if r.status_code < 400:
            for block in r.json().get("results", []):
                btype = block.get("type", "")
                bid = block.get("id", "")
                # Find the "🔗 Resources" heading
                if btype == "heading_2":
                    texts = block.get("heading_2", {}).get("rich_text", [])
                    content = "".join(t.get("text", {}).get("content", "") for t in texts)
                    if "Resources" in content:
                        resources_heading_id = bid
                # Find the "Finding resources..." placeholder paragraph
                elif btype == "paragraph" and resources_heading_id and not placeholder_id:
                    texts = block.get("paragraph", {}).get("rich_text", [])
                    content = "".join(t.get("text", {}).get("content", "") for t in texts)
                    if "Finding" in content:
                        placeholder_id = bid
        else:
            logger.warning("add_resources_to_page: could not fetch blocks %s", r.status_code)
    except Exception as e:
        logger.warning("add_resources_to_page: error fetching blocks: %s", e)

    # ── Delete the placeholder paragraph if found ─────────────────────── #
    if placeholder_id:
        try:
            requests.delete(
                f"{NOTION_BASE}/blocks/{placeholder_id}",
                headers=hdrs,
                timeout=60,
            )
            logger.info(f"🗑️ Deleted placeholder block: {placeholder_id}")
        except Exception as e:
            logger.warning("add_resources_to_page: error deleting placeholder: %s", e)

    # ── Build clean hyperlink bullet blocks (no heading, no description) ─ #
    blocks: List[dict] = []
    for res in resources[:5]:
        if not isinstance(res, dict):
            continue
        res_title = str(res.get("title", "Resource"))[:100]
        res_url = str(res.get("url", ""))

        if res_url and res_url.startswith("http"):
            blocks.append({
                "object": "block",
                "type": "bulleted_list_item",
                "bulleted_list_item": {
                    "rich_text": [
                        {
                            "type": "text",
                            "text": {
                                "content": res_title,
                                "link": {"url": res_url}
                            },
                            "annotations": {
                                "color": "blue"
                            }
                        }
                    ]
                }
            })
        else:
            blocks.append({
                "object": "block",
                "type": "bulleted_list_item",
                "bulleted_list_item": {
                    "rich_text": _rich_text(res_title)
                }
            })

    if not blocks:
        logger.warning("add_resources_to_page: no valid resource blocks built")
        return False

    # ── Append bullets — after Resources heading if found, else at end ── #
    patch_body: dict = {"children": blocks}
    if resources_heading_id:
        patch_body["after"] = resources_heading_id

    try:
        r = requests.patch(
            f"{NOTION_BASE}/blocks/{page_id}/children",
            headers=hdrs,
            json=patch_body,
            timeout=60,
        )
        if r.status_code >= 400:
            logger.warning(
                "add_resources_to_page failed: %s %s",
                r.status_code,
                r.text,
            )
            return False
        logger.info(f"✅ Resources block appended to page: {page_id}")
        return True
    except Exception as e:
        logger.warning("add_resources_to_page error: %s", e)
        return False


def create_todays_plan(tasks_today: list, notion_token: str = None) -> Optional[str]:
    """
    Creates a page under NOTION_PARENT_PAGE_ID with today's plan.
    Returns page URL or None.
    """
    parent_id = os.environ.get("NOTION_PARENT_PAGE_ID")
    if not parent_id:
        logger.warning("NOTION_PARENT_PAGE_ID is not set")
        return None

    hdrs = _headers(notion_token)
    if not hdrs:
        logger.warning("create_todays_plan: missing Notion token")
        return None

    try:
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        title = f"Today's Plan — {today}"

        children: List[dict] = [
            {
                "object": "block",
                "type": "heading_1",
                "heading_1": {"rich_text": _rich_text(today)},
            }
        ]

        for task in tasks_today or []:
            if not isinstance(task, dict):
                continue
            t_title = str(task.get("title", "") or "Untitled")
            mts = task.get("microtasks") or []
            if isinstance(mts, list):
                parts = []
                for m in mts:
                    if isinstance(m, dict):
                        parts.append(str(m.get("title", m)))
                    else:
                        parts.append(str(m))
                mt_str = ", ".join(parts) if parts else "(none)"
            else:
                mt_str = str(mts)
            bullet_text = f"{t_title} — due today: {mt_str}"
            children.append(
                {
                    "object": "block",
                    "type": "bulleted_list_item",
                    "bulleted_list_item": {"rich_text": _rich_text(bullet_text)},
                }
            )

        children.append({"object": "block", "type": "divider", "divider": {}})
        children.append(
            {
                "object": "block",
                "type": "heading_2",
                "heading_2": {"rich_text": _rich_text("Completed")},
            }
        )
        children.append(
            {
                "object": "block",
                "type": "paragraph",
                "paragraph": {"rich_text": []},
            }
        )

        body = {
            "parent": {"page_id": parent_id.strip()},
            "properties": {
                "title": {
                    "title": _rich_text(title),
                },
            },
            "children": children[:100],
        }

        r = requests.post(f"{NOTION_BASE}/pages", headers=hdrs, json=body, timeout=60)
        if r.status_code >= 400:
            logger.warning("Notion create_todays_plan failed: %s %s", r.status_code, r.text)
            return None
        data = r.json()
        return data.get("url")
    except Exception as e:
        logger.warning("Notion create_todays_plan error: %s", e)
        return None


def _build_personal_doc(
    title: str,
    deadline: str,
    em: int,
    schedule: list,
) -> List[dict]:
    """
    Personal category page content.
    Sections: Short Description, Daily Plan (bullets), Resources, Notes.
    """
    children: List[dict] = []
    hours = round(em / 60.0, 1) if em else 0.0

    # Short Description
    children.append(_h2("📋 Short Description"))
    children.append(_paragraph(
        f"Task: {title}\nDeadline: {deadline}\nEstimated effort: {em} min ({hours}h)"
    ))
    children.append(_divider())

    # Daily Plan — one bullet per schedule day
    children.append(_h2("📅 Daily Plan"))
    dates = sorted(
        {d.get("date", "") for d in schedule if isinstance(d, dict) and d.get("date")}
    )
    if dates:
        for date in dates:
            children.append(_bullet(date))
    else:
        children.append(_paragraph("No schedule days yet — run AI planning to populate."))
    children.append(_divider())

    # Resources — placeholder replaced by TinyFish
    children.append(_h2("🔗 Resources"))
    children.append(_paragraph("Finding resources..."))
    children.append(_divider())

    # Notes
    children.append(_h2("📝 Notes"))
    children.append(_paragraph(""))

    return children


def _build_study_doc(
    title: str,
    deadline: str,
    em: int,
    phases: List[str],
    phase_days: dict,
) -> List[dict]:
    """
    Study category page content.
    Sections: Short Description, Topics to Cover, Resources, Notes.
    Subpages (one per topic) are created by the caller.
    """
    children: List[dict] = []
    hours = round(em / 60.0, 1) if em else 0.0

    # Short Description
    children.append(_h2("📋 Short Description"))
    children.append(_paragraph(
        f"Task: {title}\nDeadline: {deadline}\nEstimated effort: {em} min ({hours}h)"
    ))
    children.append(_divider())

    # Topics to Cover — one bullet per unique subtopic/phase
    children.append(_h2("📚 Topics to Cover"))
    if phases:
        for i, phase in enumerate(phases, 1):
            days_for_phase = phase_days[phase]
            dates = [d.get("date", "") for d in days_for_phase if d.get("date")]
            if len(dates) > 1:
                date_range = f"  ({dates[0]} – {dates[-1]})"
            elif len(dates) == 1:
                date_range = f"  ({dates[0]})"
            else:
                date_range = ""
            children.append(_bullet(f"Topic {i}: {phase}{date_range}"))
    else:
        children.append(_paragraph(
            "No topics yet — AI planning will populate this section automatically."
        ))
    children.append(_divider())

    # Resources — placeholder replaced by TinyFish
    children.append(_h2("🔗 Resources"))
    children.append(_paragraph("Finding resources..."))
    children.append(_divider())

    # Notes
    children.append(_h2("📝 Notes"))
    children.append(_paragraph(""))

    return children


def _build_work_doc(
    title: str,
    deadline: str,
    em: int,
    phases: List[str],
    phase_days: dict,
) -> List[dict]:
    """
    Work category page content.
    Sections: Short Description, Phase Breakdown, Resources, Notes.
    Subpages (one per phase) are created by the caller.
    """
    children: List[dict] = []
    hours = round(em / 60.0, 1) if em else 0.0

    # Short Description
    children.append(_h2("📋 Short Description"))
    children.append(_paragraph(
        f"Task: {title}\nDeadline: {deadline}\nEstimated effort: {em} min ({hours}h)"
    ))
    children.append(_divider())

    # Phase Breakdown — one bullet per phase
    children.append(_h2("🔨 Phase Breakdown"))
    if phases:
        for i, phase in enumerate(phases, 1):
            days_for_phase = phase_days[phase]
            dates = [d.get("date", "") for d in days_for_phase if d.get("date")]
            if len(dates) > 1:
                date_range = f"  ({dates[0]} – {dates[-1]})"
            elif len(dates) == 1:
                date_range = f"  ({dates[0]})"
            else:
                date_range = ""
            children.append(_bullet(f"Phase {i}: {phase}{date_range}"))
    else:
        children.append(_paragraph(
            "No schedule yet — AI planning will populate this section automatically."
        ))
    children.append(_divider())

    # Resources — placeholder replaced by TinyFish
    children.append(_h2("🔗 Resources"))
    children.append(_paragraph("Finding resources..."))
    children.append(_divider())

    # Notes
    children.append(_h2("📝 Notes"))
    children.append(_paragraph(""))

    return children


def _create_phase_subpage(
    parent_page_id: str,
    phase_index: int,
    phase_name: str,
    days: list,
    hdrs: dict,
) -> Optional[str]:
    """
    Creates a subpage under the main launchpad page for a single phase.
    Each day in the phase gets a heading; each microtask becomes a to_do block.
    Returns the new subpage id or None on failure.
    """
    try:
        sub_title = f"Phase {phase_index}: {phase_name}"
        children: List[dict] = [
            {
                "object": "block",
                "type": "heading_2",
                "heading_2": {"rich_text": _rich_text(sub_title)},
            }
        ]

        for day in days:
            if not isinstance(day, dict):
                continue
            date = day.get("date", "")
            mts = day.get("microtasks") or []
            if date:
                children.append({
                    "object": "block",
                    "type": "heading_3",
                    "heading_3": {"rich_text": _rich_text(f"📅 {date}")},
                })
            for mt in (mts if isinstance(mts, list) else []):
                if not isinstance(mt, dict):
                    continue
                children.append({
                    "object": "block",
                    "type": "to_do",
                    "to_do": {
                        "rich_text": _rich_text(mt.get("title", "")),
                        "checked": bool(mt.get("completed", False)),
                    },
                })

        body = {
            "parent": {"page_id": parent_page_id},
            "properties": {"title": {"title": _rich_text(sub_title)}},
            "children": children[:100],
        }
        r = requests.post(f"{NOTION_BASE}/pages", headers=hdrs, json=body, timeout=60)
        if r.status_code >= 400:
            logger.warning("_create_phase_subpage failed: %s %s", r.status_code, r.text)
            return None
        return r.json().get("id")
    except Exception as e:
        logger.warning("_create_phase_subpage error: %s", e)
        return None


def create_launchpad_doc(
    title: str,
    deadline: str,
    estimated_minutes: int,
    schedule: list,
    category: str = "Work",
    notion_token: str = None,
    parent_page_id: Optional[str] = None,
) -> Optional[dict]:
    """
    Creates an execution-focused launchpad page in Notion with 5 structured sections,
    an inline Progress Tracker database, and one subpage per phase.
    Returns {"page_id": str, "page_url": str, "parent_page_id": str, "breakdown_db_id": str} or None on failure.
    """
    parent_id = (parent_page_id or "").strip() or (
        os.environ.get("NOTION_PARENT_PAGE_ID") or ""
    ).strip()
    if not parent_id:
        logger.warning("create_launchpad_doc: NOTION_PARENT_PAGE_ID is not set and no parent_page_id")
        return None

    hdrs = _headers(notion_token)
    if not hdrs:
        logger.warning("create_launchpad_doc: missing Notion token")
        return None

    used_parent = parent_id

    try:
        em = int(estimated_minutes) if estimated_minutes is not None else 0
    except (TypeError, ValueError):
        em = 0

    # Normalize category
    cat = category.strip().capitalize() if category else "Work"
    if cat not in ("Personal", "Study", "Work"):
        cat = "Work"

    logger.info("create_launchpad_doc: category=%s, schedule_days=%d", cat, len(schedule or []))

    # Collect unique steps in order from schedule
    unique_steps = list(dict.fromkeys([
        day.get("subtask", "").strip()
        for day in (schedule or [])
        if isinstance(day, dict) and day.get("subtask", "").strip()
    ]))

    # ── Step A: Build initial page blocks ────────────────────────────── #
    # Only Task Overview + Expected Output + Progress Tracker heading.
    # Workflow/Notes/Resources are appended AFTER the database (Step C) so
    # the inline database visually appears right below the Progress Tracker heading.
    children: List[dict] = []

    # ── Section 1: Task Overview ──────────────────────────────────────── #
    hours = em // 60
    children.append(_h2("🚀 Task Overview"))
    children.append(_paragraph(
        f"Task: {title} | Deadline: {deadline} | Estimated: {em} min ({hours}h) | Category: {cat}"
    ))
    children.append(_divider())

    # ── Section 2: Expected Output ────────────────────────────────────── #
    children.append(_h2("🎯 Expected Output"))
    if cat == "Personal":
        output_text = f"Complete {title} consistently until deadline. Track progress daily."
    elif cat == "Study":
        output_text = f"Master the key concepts of {title}. Be able to explain and apply each topic."
    else:
        output_text = f"Deliver a fully completed {title} by {deadline} with all phases reviewed."
    children.append(_paragraph(output_text))
    children.append(_divider())

    # ── Section 3: Progress Tracker heading only (database follows via API) ── #
    children.append(_h2("📋 Progress Tracker"))
    children.append(_divider())

    # ── POST the page ─────────────────────────────────────────────────── #
    try:
        body = {
            "parent": {"page_id": used_parent.strip()},
            "properties": {
                "title": {"title": _rich_text(f"🚀 Let's Get Started — {title}")}
            },
            "children": children[:100],
        }
        r = requests.post(f"{NOTION_BASE}/pages", headers=hdrs, json=body, timeout=60)
        if r.status_code == 404:
            fallback = _search_first_accessible_page_id(notion_token)
            if fallback and fallback != used_parent:
                logger.warning(
                    "create_launchpad_doc: parent page not accessible (404); "
                    "retrying under first page from workspace search"
                )
                used_parent = fallback
                body["parent"] = {"page_id": used_parent.strip()}
                r = requests.post(
                    f"{NOTION_BASE}/pages", headers=hdrs, json=body, timeout=60
                )
        if r.status_code >= 400:
            logger.warning(
                "create_launchpad_doc: create page failed %s %s", r.status_code, r.text
            )
            return None
        data = r.json()
        main_page_id = data.get("id")
        main_page_url = data.get("url")
        if not main_page_id:
            logger.warning("create_launchpad_doc: no page id in response: %s", data)
            return None

        logger.info("✅ create_launchpad_doc: page created %s (category=%s)", main_page_id, cat)

        # ── Step B: Create Progress Tracker inline database ───────────── #
        breakdown_db_id = ""
        try:
            db_payload = {
                "parent": {"type": "page_id", "page_id": main_page_id},
                "is_inline": True,
                "title": [{"type": "text", "text": {"content": "Progress Tracker"}}],
                "properties": {
                    "Step": {"title": {}},
                    "Status": {
                        "select": {
                            "options": [
                                {"name": "To Do", "color": "red"},
                                {"name": "In Progress", "color": "yellow"},
                                {"name": "Done", "color": "green"},
                            ]
                        }
                    },
                    "Phase": {"rich_text": {}},
                    "Order": {"number": {}},
                },
            }
            db_resp = requests.post(
                f"{NOTION_BASE}/databases",
                headers=hdrs,
                json=db_payload,
                timeout=30,
            )
            if db_resp.status_code < 400:
                breakdown_db_id = db_resp.json().get("id", "")
                logger.info(f"✅ Created Progress Tracker database: {breakdown_db_id}")
            else:
                logger.warning(
                    "create_launchpad_doc: Progress Tracker database creation failed: %s %s",
                    db_resp.status_code, db_resp.text,
                )
        except Exception as e:
            logger.warning("create_launchpad_doc: Progress Tracker database error: %s", e)

        # ── Populate Progress Tracker database rows ───────────────────── #
        if breakdown_db_id and unique_steps:
            for i, step in enumerate(unique_steps):
                try:
                    requests.post(
                        f"{NOTION_BASE}/pages",
                        headers=hdrs,
                        json={
                            "parent": {"database_id": breakdown_db_id},
                            "properties": {
                                "Step": {"title": [{"text": {"content": step[:100]}}]},
                                "Status": {"select": {"name": "To Do"}},
                                "Phase": {"rich_text": [{"text": {"content": f"Phase {i + 1}"}}]},
                                "Order": {"number": i + 1},
                            },
                        },
                        timeout=30,
                    )
                except Exception as e:
                    logger.warning("create_launchpad_doc: row insert error for step %s: %s", step, e)

            # ── Set default sort: Order ascending ─────────────────────── #
            try:
                requests.patch(
                    f"{NOTION_BASE}/databases/{breakdown_db_id}",
                    headers=hdrs,
                    json={"sorts": [{"property": "Order", "direction": "ascending"}]},
                    timeout=30,
                )
            except Exception as e:
                logger.warning("create_launchpad_doc: sort patch error: %s", e)

        # ── Step C: Append Workflow + Notes (with phases inline) + Resources ── #
        # Single patch call so all sections land in the correct order.
        all_blocks: List[dict] = []

        # Workflow Diagram section
        all_blocks.append(_h2("🎨 Workflow Diagram"))
        all_blocks.append(_paragraph("Generating your workflow diagram... check back in 2 minutes."))
        all_blocks.append(_divider())

        # Notes section with phase headings + microtasks inline
        all_blocks.append(_h2("📝 Notes"))
        for i, step in enumerate(unique_steps):
            microtasks: List[dict] = [
                mt
                for day in (schedule or [])
                if isinstance(day, dict) and day.get("subtask", "").strip() == step
                for mt in (day.get("microtasks") or [])
            ]
            all_blocks.append({
                "object": "block",
                "type": "heading_3",
                "heading_3": {"rich_text": _rich_text(f"Phase {i + 1} — {step}")},
            })
            for mt in microtasks[:10]:
                all_blocks.append({
                    "object": "block",
                    "type": "bulleted_list_item",
                    "bulleted_list_item": {
                        "rich_text": _rich_text(mt.get("title", "")[:200]),
                    },
                })
            all_blocks.append({"object": "block", "type": "divider", "divider": {}})

        # Resources section
        all_blocks.append(_h2("🔗 Resources"))
        all_blocks.append(_paragraph("Finding best resources..."))

        try:
            requests.patch(
                f"{NOTION_BASE}/blocks/{main_page_id}/children",
                headers=hdrs,
                json={"children": all_blocks[:100]},
                timeout=30,
            )
            logger.info("✅ Appended Workflow + Notes (phases) + Resources in single call")
        except Exception as e:
            logger.warning("create_launchpad_doc: all_blocks append error: %s", e)

        return {
            "page_id": main_page_id,
            "page_url": main_page_url,
            "parent_page_id": used_parent,
            "breakdown_db_id": breakdown_db_id,
        }

    except Exception as e:
        logger.warning("create_launchpad_doc error: %s", e)
        return None


def _numbered(text: str) -> dict:
    return {"object": "block", "type": "numbered_list_item",
            "numbered_list_item": {"rich_text": _rich_text(text)}}


def _make_page(parent_id: str, title: str, children: List[dict], hdrs: dict) -> Optional[dict]:
    """POST a page under parent_id. Returns Notion response dict or None."""
    body = {
        "parent": {"page_id": parent_id.strip()},
        "properties": {"title": {"title": _rich_text(title)}},
        "children": children[:100],
    }
    try:
        r = requests.post(f"{NOTION_BASE}/pages", headers=hdrs, json=body, timeout=60)
        if r.status_code >= 400:
            logger.warning("_make_page failed: %s %s", r.status_code, r.text)
            return None
        return r.json()
    except Exception as e:
        logger.warning("_make_page error: %s", e)
        return None


def _collect_phases(schedule: list):
    """Return (ordered phases list, phase_name -> [days] dict)."""
    seen: set = set()
    phases: List[str] = []
    phase_days: dict = {}
    for day in (schedule or []):
        if not isinstance(day, dict):
            continue
        subtask = (day.get("subtask") or "").strip()
        if not subtask:
            subtask = f"Session — {day.get('date', 'unknown')}"
        if subtask not in seen:
            seen.add(subtask)
            phases.append(subtask)
            phase_days[subtask] = []
        phase_days[subtask].append(day)
    return phases, phase_days


# ── Public category-specific doc creators ───────────────────────────────── #

def create_personal_doc(title: str, deadline: str, schedule: list, notion_token: str = None) -> Optional[str]:
    """
    Creates a Personal launchpad page titled '[title] — Let's Get Started'.
    Sections: Overview, Daily Time Blocks (to_do per day), Habit Tracker (table), Notes.
    Returns page URL or None.
    """
    parent_id = os.environ.get("NOTION_PARENT_PAGE_ID")
    if not parent_id:
        logger.warning("create_personal_doc: NOTION_PARENT_PAGE_ID not set")
        return None
    hdrs = _headers(notion_token)
    if not hdrs:
        logger.warning("create_personal_doc: missing Notion token")
        return None

    children: List[dict] = []

    # Overview
    children.append(_h2("Overview"))
    children.append(_paragraph(f"Your personal plan for {title}. Starts today, deadline {deadline}."))

    # Daily Time Blocks
    children.append(_h2("Daily Time Blocks"))
    for day in (schedule or []):
        if not isinstance(day, dict):
            continue
        date = day.get("date", "")
        subtask = day.get("subtask", "") or ""
        n = len(day.get("microtasks") or [])
        children.append(_todo(f"{date} — {subtask} — {n} sessions"))

    # Habit Tracker
    children.append(_h2("Habit Tracker"))
    rows: List[List[str]] = [["Day", "Planned", "Done"]]
    for day in (schedule or []):
        if not isinstance(day, dict):
            continue
        date = day.get("date", "")
        subtask = day.get("subtask", "") or ""
        rows.append([date, subtask, ""])
    if len(rows) > 1:
        children.append(_table_block(rows))
    else:
        children.append(_paragraph("No schedule days yet."))

    # Notes
    children.append(_h2("Notes"))
    children.append(_paragraph(""))

    data = _make_page(parent_id, f"{title} — Let's Get Started", children, hdrs)
    if not data:
        return None
    url = data.get("url")
    logger.info("✅ create_personal_doc: %s", url)
    return url


def create_study_doc(title: str, deadline: str, schedule: list, notion_token: str = None) -> Optional[str]:
    """
    Creates a Study launchpad page titled '[title] — Study Kit'.
    Sections: What You're Covering (bullets), Daily Study Plan (to_do), Resources, Workflow, Notes.
    Also creates one subpage per unique subtask with Microtasks.
    Returns page URL or None.
    """
    parent_id = os.environ.get("NOTION_PARENT_PAGE_ID")
    if not parent_id:
        logger.warning("create_study_doc: NOTION_PARENT_PAGE_ID not set")
        return None
    hdrs = _headers(notion_token)
    if not hdrs:
        logger.warning("create_study_doc: missing Notion token")
        return None

    phases, phase_days = _collect_phases(schedule)

    children: List[dict] = []

    # What You're Covering
    children.append(_h2("What You're Covering"))
    if phases:
        for phase in phases:
            children.append(_bullet(phase))
    else:
        children.append(_paragraph("No topics yet — run AI planning to populate."))

    # Daily Study Plan
    children.append(_h2("Daily Study Plan"))
    for day in (schedule or []):
        if not isinstance(day, dict):
            continue
        date = day.get("date", "")
        subtask = day.get("subtask", "") or ""
        children.append(_todo(f"{date} — {subtask}"))

    # Resources
    children.append(_h2("Resources"))
    children.append(_paragraph("Add textbooks, online courses, videos, and study references here."))

    # Workflow
    children.append(_h2("Workflow"))
    children.append(_paragraph("Add your study workflow, tools, and review process here."))

    # Notes
    children.append(_h2("Notes"))
    children.append(_paragraph(""))

    data = _make_page(parent_id, f"{title} — Study Kit", children, hdrs)
    if not data:
        return None
    main_page_id = data.get("id")
    url = data.get("url")

    # Subpages: one per unique subtask — "Microtasks" heading + to_do per microtask
    for phase in phases:
        days = phase_days[phase]
        sub_children: List[dict] = [_h2("Microtasks")]
        for day in days:
            for mt in (day.get("microtasks") or []):
                if isinstance(mt, dict):
                    sub_children.append(_todo(mt.get("title", ""), bool(mt.get("completed"))))
        _make_page(main_page_id, phase, sub_children, hdrs)

    logger.info("✅ create_study_doc: %s", url)
    return url


def create_work_doc(title: str, deadline: str, schedule: list, notion_token: str = None) -> Optional[str]:
    """
    Creates a Work launchpad page titled '[title] — Project Guide'.
    Sections: Project Overview (paragraph), Phases (numbered list), Workflow, Tools & References, Notes.
    Also creates one subpage per unique phase titled 'Phase — [subtask]' with Steps + Notes.
    Returns page URL or None.
    """
    parent_id = os.environ.get("NOTION_PARENT_PAGE_ID")
    if not parent_id:
        logger.warning("create_work_doc: NOTION_PARENT_PAGE_ID not set")
        return None
    hdrs = _headers(notion_token)
    if not hdrs:
        logger.warning("create_work_doc: missing Notion token")
        return None

    phases, phase_days = _collect_phases(schedule)

    children: List[dict] = []

    # Project Overview
    children.append(_h2("Project Overview"))
    children.append(_paragraph(f"Your project plan for {title}. Deadline: {deadline}."))

    # Phases
    children.append(_h2("Phases"))
    if phases:
        for phase in phases:
            children.append(_numbered(phase))
    else:
        children.append(_paragraph("No phases yet — run AI planning to populate."))

    # Workflow
    children.append(_h2("Workflow"))
    children.append(_paragraph("Add your workflow, tools, and processes here."))

    # Tools & References
    children.append(_h2("Tools & References"))
    children.append(_paragraph("Add tools, libraries, links, and assets you'll need for this project."))

    # Notes
    children.append(_h2("Notes"))
    children.append(_paragraph(""))

    data = _make_page(parent_id, f"{title} — Project Guide", children, hdrs)
    if not data:
        return None
    main_page_id = data.get("id")
    url = data.get("url")

    # Subpages: one per phase — "Steps" + to_do blocks + divider + "Notes"
    for phase in phases:
        days = phase_days[phase]
        sub_children: List[dict] = [_h2("Steps")]
        for day in days:
            for mt in (day.get("microtasks") or []):
                if isinstance(mt, dict):
                    sub_children.append(_todo(mt.get("title", ""), bool(mt.get("completed"))))
        sub_children.append(_divider())
        sub_children.append(_h2("Notes"))
        sub_children.append(_paragraph(""))
        _make_page(main_page_id, f"Phase — {phase}", sub_children, hdrs)

    logger.info("✅ create_work_doc: %s", url)
    return url


def update_task_status(page_id: str, status: str, notion_token: str = None) -> bool:
    """Updates Status select on a Notion page. Returns True on success."""
    if not page_id or not page_id.strip():
        return False

    hdrs = _headers(notion_token)
    if not hdrs:
        logger.warning("update_task_status: missing Notion token")
        return False

    allowed = {"Pending", "Completed"}
    st = status if status in allowed else "Pending"

    try:
        body = {"properties": {"Status": {"select": {"name": st}}}}
        r = requests.patch(
            f"{NOTION_BASE}/pages/{page_id}",
            headers=hdrs,
            json=body,
            timeout=30,
        )
        if r.status_code >= 400:
            logger.warning("Notion update_task_status failed: %s %s", r.status_code, r.text)
            return False
        return True
    except Exception as e:
        logger.warning("Notion update_task_status error: %s", e)
        return False
