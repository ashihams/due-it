import os
import requests
import logging

logger = logging.getLogger(__name__)

TINYFISH_API_URL = "https://agent.tinyfish.ai/v1/automation/run-sse"


def run_automation(url: str, goal: str) -> dict:
    """Run a TinyFish web automation and return the result."""
    api_key = os.environ.get("TINYFISH_API_KEY")
    if not api_key:
        logger.warning("TINYFISH_API_KEY not set")
        return {"success": False, "error": "API key not configured"}
    try:
        response = requests.post(
            TINYFISH_API_URL,
            headers={
                "X-API-Key": api_key,
                "Content-Type": "application/json",
                "Accept": "text/event-stream",
            },
            json={"url": url, "goal": goal},
            timeout=120,
            stream=True,
        )
        if response.status_code >= 400:
            logger.warning(f"TinyFish error: {response.status_code} {response.text}")
            return {"success": False, "error": f"Status {response.status_code}"}
        result_text = ""
        for line in response.iter_lines():
            if line:
                decoded = line.decode("utf-8") if isinstance(line, bytes) else line
                if decoded.startswith("data:"):
                    result_text += decoded[5:].strip() + "\n"
        return {"success": True, "result": result_text.strip()}
    except Exception as e:
        logger.warning(f"TinyFish run_automation error: {e}")
        return {"success": False, "error": str(e)}


def scrape_resources(topic: str, category: str) -> dict:
    """
    Use TinyFish to scrape real resources for a given topic.
    Returns structured list of resources found on the web.
    """
    _quality_instructions = """
        Return only the top 3 to 5 most relevant, high-quality results.
        Prioritize official documentation, well-known educational platforms (Coursera, edX, Khan Academy, MIT OpenCourseWare, freeCodeCamp, official docs), and authoritative guides.
        Avoid random blogs, forums, or low-quality sites.
        Return ONLY a JSON array with keys: title, url, description."""

    if category.lower() == "study":
        url = f"https://duckduckgo.com/?q={topic.replace(' ', '+')}+free+course+tutorial+pdf&ia=web"
        goal = f"""Search for learning resources about "{topic}".
        Find the most useful results from the DuckDuckGo search results.
        For each result extract: title, url, and one line description.
        {_quality_instructions}"""
    elif category.lower() == "work":
        url = f"https://duckduckgo.com/?q={topic.replace(' ', '+')}+tutorial+guide+documentation&ia=web"
        goal = f"""Search for technical resources and guides about "{topic}".
        Find the most useful results from the DuckDuckGo search results.
        For each result extract: title, url, and one line description.
        {_quality_instructions}"""
    else:
        url = f"https://duckduckgo.com/?q={topic.replace(' ', '+')}+tips+guide+how+to&ia=web"
        goal = f"""Search for tips and guides about "{topic}".
        Find the most useful results from the DuckDuckGo search results.
        For each result extract: title, url, and one line description.
        {_quality_instructions}"""
    return run_automation(url, goal)


def create_excalidraw_workflow(title: str, category: str, steps: list) -> dict:
    if not steps:
        steps = ["Research", "Plan", "Execute", "Review", "Deliver"]

    # Clean and limit steps
    clean_steps = [str(s).strip()[:30] for s in steps[:6] if s]
    steps_numbered = "\n".join([f"{i+1}. {s}" for i, s in enumerate(clean_steps)])

    # Generate Mermaid code from actual steps
    mermaid_nodes = "\n    ".join([f'S{i}["{s}"]' for i, s in enumerate(clean_steps)])
    mermaid_arrows = "\n    ".join([f"S{i} --> S{i+1}" for i in range(len(clean_steps)-1)])
    mermaid_code = f"flowchart LR\n    {mermaid_nodes}\n    {mermaid_arrows}"

    logger.info(f"TinyFish Excalidraw steps: {clean_steps}")

    goal = f"""Go to https://excalidraw.com in the browser.

Create a workflow diagram for: "{title}"
Steps: {steps_numbered}

STEP 1: Insert the diagram using Mermaid:
- Click hamburger menu (☰) top left
- Click "Mermaid to Excalidraw" or "Paste diagram"
- Clear the editor and paste this exact code:
{mermaid_code}
- Click Insert

STEP 2: Start a collaboration session to get an EDITABLE link:
- Click the Live Collaboration button (person+ icon) in top right
- Click "Start session"
- Wait for the room URL to appear in the browser address bar
- The URL looks like: https://excalidraw.com/#room=XXXX,YYYY

STEP 3: Return the room URL from the browser address bar.
Return ONLY the URL starting with https://excalidraw.com/#room=
Do NOT return a #json= URL."""

    return run_automation("https://excalidraw.com", goal)
