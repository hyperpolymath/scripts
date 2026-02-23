import json
import datetime
import uuid

def unix_timestamp(dt):
    # Windows/Chrome timestamp (microseconds since Jan 1, 1601)
    return int((dt - datetime.datetime(1601, 1, 1)).total_seconds() * 1000000)

themes = {
    "Tech & Programming": ["github", "programming", "docker", "server", "code", "dev", "tech", "node", "python", "rust", "npm", "stack", "api", "web", "cloud", "aws", "google", "microsoft", "apple", "app", "software"],
    "Linux & OS": ["fedora", "linux", "ubuntu", "debian", "kernel", "cli", "shell", "bash", "terminal", "desktop", "os", "system", "config"],
    "News & Finance": ["news", "breaking", "msn", "trump", "politics", "economy", "market", "finance", "bank", "money", "stock", "crypto", "bitcoin", "business", "invest", "trading"],
    "Psychology & Growth": ["psychology", "mental", "self", "growth", "happiness", "manipulation", "relationships", "advice", "life", "wellness", "mindset", "success", "productivity"],
    "Art, Culture & Design": ["art", "artist", "design", "museum", "culture", "style", "creative", "photo", "music", "history", "philosophy", "books", "writing"],
    "Lifestyle & Health": ["food", "cooking", "recipe", "health", "fitness", "yoga", "travel", "holiday", "home", "garden", "shopping", "amazon", "buy", "deal"],
    "Education & Career": ["learn", "course", "study", "university", "school", "job", "career", "resume", "cv", "interview", "skills", "training"],
    "Media & Social": ["youtube", "video", "tv", "movie", "entertainment", "facebook", "twitter", "x.com", "instagram", "reddit", "watch", "podcast"]
}

def categorize(line):
    line_lower = line.lower()
    for theme, keywords in themes.items():
        if any(keyword in line_lower for keyword in keywords):
            return theme
    return "Uncategorized"

all_bookmarks = {}

try:
    with open("/tmp/firefox_bookmarks.txt", "r") as f:
        for line in f:
            theme = categorize(line)
            all_bookmarks.setdefault(theme, []).append(line.strip())

    with open("/tmp/edge_bookmarks.txt", "r") as f:
        for line in f:
            theme = categorize(line)
            all_bookmarks.setdefault(theme, []).append(line.strip())

    new_roots = {
        "bookmark_bar": {
            "children": [],
            "date_added": str(unix_timestamp(datetime.datetime.now())),
            "date_last_used": "0",
            "guid": str(uuid.uuid4()),
            "id": "1",
            "name": "Favorites Bar",
            "type": "folder"
        },
        "other": { "children": [], "date_added": "0", "date_last_used": "0", "guid": str(uuid.uuid4()), "id": "2", "name": "Other Favorites", "type": "folder" },
        "synced": { "children": [], "date_added": "0", "date_last_used": "0", "guid": str(uuid.uuid4()), "id": "3", "name": "Mobile Favorites", "type": "folder" }
    }

    current_id = 4
    sorted_themes = sorted([t for t in all_bookmarks.keys() if t != "Uncategorized"]) + ["Uncategorized"]
    
    for theme in sorted_themes:
        if theme in all_bookmarks:
            unique_items = sorted(list(set(all_bookmarks[theme])))
            folder = {
                "date_added": str(unix_timestamp(datetime.datetime.now())),
                "date_last_used": "0",
                "guid": str(uuid.uuid4()),
                "id": str(current_id),
                "name": theme,
                "type": "folder",
                "children": []
            }
            current_id += 1
            for item in unique_items:
                parts = item.split("|")
                if len(parts) == 2:
                    folder["children"].append({
                        "date_added": str(unix_timestamp(datetime.datetime.now())),
                        "date_last_used": "0",
                        "guid": str(uuid.uuid4()),
                        "id": str(current_id),
                        "name": parts[0],
                        "type": "url",
                        "url": parts[1]
                    })
                    current_id += 1
            new_roots["bookmark_bar"]["children"].append(folder)

    output = {
        "checksum": "", # Edge should re-calc
        "roots": new_roots,
        "version": 1
    }

    with open("/home/hyper/.var/app/com.microsoft.EdgeDev/config/microsoft-edge-dev/Default/Bookmarks", "w") as f:
        json.dump(output, f, indent=3)
    
    print("Success: Edge Bookmarks file overwritten.")
except Exception as e:
    print(f"Error: {e}")
