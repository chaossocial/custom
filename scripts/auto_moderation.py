

from mastodon import Mastodon
from pprint import pprint
from distutils.util import strtobool
from time import sleep
from datetime import datetime, timedelta
import os.path
import json

def mastodon_login():

    SCOPES=["admin:read:reports","admin:write:reports", "admin:read:accounts", "admin:write:accounts"]

    if os.path.isfile("mastodon_api.access"):
        print("Login found, start processing!")
        return Mastodon(access_token="mastodon_api.access")
    else:
        print("No login found, start login!")
        api_base_url = input("Please enter api_base_url [https://social.example.com]: ")
        credentials = Mastodon.create_app("auto_moderation.py", api_base_url=api_base_url, scopes=SCOPES, to_file="mastodon_api.auth")
        m = Mastodon(client_id="mastodon_api.auth", api_base_url=api_base_url)
        auth_url = m.auth_request_url(scopes=SCOPES)
        print("Please open this URL in your Browser: " + auth_url)
        auth_token = input("Please insert auth token: ")
        access_token = m.log_in(code=auth_token, to_file="mastodon_api.access", scopes=SCOPES)
        return Mastodon(access_token="mastodon_api.access")
        print("Login done, start processing!")

def check_language(status):
    if status["language"] == "en":
        return True
    else:
        return False

def check_content(status):
    matches = [
        "string1",
        "string2"]
    return any(x in status["content"] for x in matches)

def check_hashtags(status):
    matches = ["tag1", "tag2"]
    for tag in status["tags"]:
        if tag['name'] in matches:
            return True
    return False

def check_media(status):
    if status["media_attachments"]:
        return True
    else: 
        return False

def check_mentions(status):
    if len(status["mentions"]) > 1:
        return True
    else: 
        return False

def check_account_creation(account):
    if account["created_at"].date() >= datetime.today().date()- timedelta(days = 1):
        return True
    else: 
        return False

def check_account_name(account):
    if len(account["username"])== 23:
        return True
    else:
        return False

def update_stats(stats, account):
    if account["domain"] in stats:
        stats[account["domain"]] += 1
    else:
        stats[account["domain"]] = 1

DONT_ASK = True
stats = {}
last_report_id = ""
m = mastodon_login()
while True:
    reports = m.admin_reports(min_id=last_report_id)
    if not reports:
        print(".", end="", flush=True)
        sleep(30)
    else:
        with open("spam_domain_stats.json", 'r') as stats_file:
            stats = json.load(stats_file)
        for report in reports:
            mentions = 0
            hashtag = False
            image = False
            content = False
            language = False
            rep_account = report["target_account"]
            if (check_account_creation(rep_account)
                and check_account_name(rep_account)
            ):
                for status in report["statuses"]:
                    mentions += check_mentions(status)
                    image += check_media(status) 
                    hashtag += check_hashtags(status)
                    content += check_content(status)
                    language += check_language(status)
                print("\nContent: " + str(content) + " Image: " + str(image) + " Hashtag: " + str(hashtag) + " Mentions: " + str(mentions) + " Language: " +str(language))
                if image or hashtag or content and mentions:
                    if DONT_ASK or strtobool(input(rep_account["username"] + " looks like a spam user name. Suspend?[y/n] ")):
                        m.admin_account_moderate(id=report["target_account"]["account"]["id"],action="suspend", report_id=report["id"])
                        print("Spam dedection successful, blocking user: " + rep_account["username"] + "@" + rep_account["domain"] + " ✅")
                        update_stats(stats, rep_account)
            last_report_id = report_id=report["id"]
        with open("spam_domain_stats.json", 'w') as stats_file:
            json.dump(stats, stats_file)
        sleep(10)

