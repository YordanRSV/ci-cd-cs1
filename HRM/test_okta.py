import okta_handler

if __name__ == '__main__':
    users = okta_handler.get_all_users_info()
    print(f"Found {len(users)} users")
    for u in users[:10]:
        print(u)
