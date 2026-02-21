import datetime

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

    html_path = "/var/mnt/eclipse/repos/organized_bookmarks.html"
    with open(html_path, "w") as f:
        f.write('<!DOCTYPE NETSCAPE-Bookmark-file-1>\n')
        f.write('<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">\n')
        f.write('<TITLE>Bookmarks</TITLE>\n')
        f.write('<H1>Bookmarks</H1>\n')
        f.write('<DL><p>\n')
        
        sorted_themes = sorted([t for t in all_bookmarks.keys() if t != "Uncategorized"]) + ["Uncategorized"]
        
        for theme in sorted_themes:
            if theme in all_bookmarks:
                f.write(f'    <DT><H3>{theme}</H3>\n')
                f.write('    <DL><p>\n')
                unique_items = sorted(list(set(all_bookmarks[theme])))
                for item in unique_items:
                    parts = item.split("|")
                    if len(parts) == 2:
                        name, url = parts[0], parts[1]
                        name = name.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")
                        f.write(f'        <DT><A HREF="{url}">{name}</A>\n')
                f.write('    </DL><p>\n')
        
        f.write('</DL><p>\n')
    
    print(f"Success: {html_path} generated.")
except Exception as e:
    print(f"Error: {e}")
