"""Downloads every file of a free ("name your own price", $0 allowed) itch.io asset page.

    python -I tools/itch_download.py https://luizmelo.itch.io/wizard-pack <out dir>

It walks the same steps as pressing "Download Now" then "No thanks, just take me to the downloads": it asks the
page for a download link, opens the download page, and asks for each upload's file. Only use it on pages whose
licence you have read and that allow free downloads. Paid pages simply fail.

Download into a new, empty folder outside the project (the scratchpad), never into the game folder: downloads are
untrusted until you have looked at them.
"""

import http.cookiejar
import json
import os
import re
import sys
import urllib.parse
import urllib.request


def main():
    page, out = sys.argv[1].rstrip("/"), sys.argv[2]
    os.makedirs(out, exist_ok=True)
    jar = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    opener.addheaders = [("User-Agent", "Mozilla/5.0"), ("X-Requested-With", "XMLHttpRequest")]

    def get(url):
        return opener.open(url).read().decode("utf-8", "replace")

    def post(url, data):
        return json.loads(opener.open(url, urllib.parse.urlencode(data).encode()).read())

    def csrf(html):
        return re.search(r'name="csrf_token" value="([^"]+)"', html).group(1)

    html = get(page)
    answer = post(page + "/download_url", {"csrf_token": csrf(html)})
    if "url" not in answer:
        print("no free download on this page:", answer)
        return
    dl_html = get(answer["url"])
    for upload in sorted(set(re.findall(r'data-upload_id="(\d+)"', dl_html))):
        # Note: no "key" parameter. Sending the key from the download link makes itch answer "invalid key".
        res = post(f"{page}/file/{upload}?source=game_download", {"csrf_token": csrf(dl_html)})
        if "url" not in res:
            print("failed", upload, res)
            continue
        resp = opener.open(res["url"])
        name = re.search(r'filename="?([^";]+)', resp.headers.get("Content-Disposition", ""))
        name = name.group(1) if name else upload
        with open(os.path.join(out, name), "wb") as f:
            f.write(resp.read())
        print("got", name)


if __name__ == "__main__":
    main()
