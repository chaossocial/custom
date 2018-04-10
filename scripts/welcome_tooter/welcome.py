"""
"""
import os

from mastodon import Mastodon

PATH = os.path.dirname(__file__)
APP = 'welcometooter'
CLIENTCRED = os.path.join(PATH, f'{APP}_clientcred.secret')
USERCRED = os.path.join(PATH, f'{APP}_usercred.secret')
FOLLOW_LIST = os.path.join(PATH, 'follower_list')

INSTANCE = 'https://chaos.social'
USER_EMAIL = os.environ.get('WELCOME_USER_EMAIL') or 'too@t.er'
USER_PASS = os.environ.get('WELCOME_USER_PASS') or 'supersecret'
DRY_RUN = os.environ.get('WELCOME_DO_NOT_SEND') or True
MESSAGE = 'This is your automated welcome message, I will only bother you this once.'


def get_all_followers(account_id, mastodon):
    followers = mastodon.account_followers(account_id)
    while followers[-1].get('_pagination_next') and followers[-1].get('_pagination_next').get('max_id'):
        followers += mastodon.account_followers(account_id, max_id=followers[-1].get('_pagination_next').get('max_id'))
    return followers


def main():
    if not os.path.exists(CLIENTCRED):
        Mastodon.create_app(APP, api_base_url=INSTANCE, to_file=CLIENTCRED)
    mastodon = Mastodon(client_id=CLIENTCRED, api_base_url='https://chaos.social')
    mastodon.log_in(USER_EMAIL, USER_PASS, to_file=USERCRED)

    my_id = mastodon.account_verify_credentials()['id']
    current_followers = get_all_followers(my_id, mastodon)
    print(f'You currently have {len(current_followers)} followers.')

    local_followers = [follower for follower in current_followers if follower.get('url', '').startswith(INSTANCE)]
    follower_nicks = set(follower['username'] for follower in local_followers)
    print(f'{len(local_followers)} of those are local.')

    if os.path.exists(FOLLOW_LIST):
        with open(FOLLOW_LIST) as f:
            previous_nicks = set([line.strip() for line in f.read().split('\n') if line.strip()])
    else:
        previous_nicks = set()

    new_nicks = follower_nicks - previous_nicks
    print(f'{len(new_nicks)} of *those* are new.')

    if not DRY_RUN:
        for nick in new_nicks:
            mastodon.status_post(f'@{nick} {MESSAGE}', visibility='direct')
    else:
        print(f'This is a DRY RUN. Would have sent messages to {len(new_nicks)} users: {new_nicks}')

    with open(FOLLOW_LIST, 'w') as f:
        f.write('\n'.join(follower_nicks))


if __name__ == '__main__':
    main()
