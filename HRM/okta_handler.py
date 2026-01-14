import os
import requests
from urllib.parse import urljoin


OKTA_DOMAIN = os.getenv('OKTA_DOMAIN')
OKTA_API_TOKEN = os.getenv('OKTA_API_TOKEN')

if not OKTA_DOMAIN or not OKTA_API_TOKEN:
    raise EnvironmentError('OKTA_DOMAIN and OKTA_API_TOKEN must be set in environment')

HEADERS = {
    'Authorization': f'SSWS {OKTA_API_TOKEN}',
    'Accept': 'application/json',
    'Content-Type': 'application/json'
}


def _okta_get(path, params=None):
    url = urljoin(OKTA_DOMAIN, path)
    resp = requests.get(url, headers=HEADERS, params=params, timeout=10)
    resp.raise_for_status()
    return resp.json()


def _okta_post(path, json_body=None):
    url = urljoin(OKTA_DOMAIN, path)
    resp = requests.post(url, headers=HEADERS, json=json_body, timeout=10)
    resp.raise_for_status()
    return resp


def _okta_delete(path):
    url = urljoin(OKTA_DOMAIN, path)
    resp = requests.delete(url, headers=HEADERS, timeout=10)
    if resp.status_code not in (200, 204):
        resp.raise_for_status()
    return resp


def get_all_users_info():
    users = []
    data = _okta_get('/api/v1/users')
    for u in data:
        profile = u.get('profile', {})
        users.append([
            u.get('id'),
            profile.get('displayName') or f"{profile.get('firstName','')} {profile.get('lastName','')}",
            profile.get('title') or 'No Title',
            profile.get('login') or profile.get('email')
        ])
    return users


def get_group_by_id(group_id):
    return _okta_get(f'/api/v1/groups/{group_id}')


def get_group_by_user_id(user_id):
    groups = _okta_get(f'/api/v1/users/{user_id}/groups')
    result = []
    for g in groups:
        result.append([g.get('id'), g.get('profile', {}).get('name')])
    return result


def get_group_members(group_id):
    members = _okta_get(f'/api/v1/groups/{group_id}/users')
    result = []
    for m in members:
        profile = m.get('profile', {})
        result.append([
            m.get('id'),
            profile.get('displayName') or f"{profile.get('firstName','')} {profile.get('lastName','')}",
            profile.get('login') or profile.get('email')
        ])
    return result


def get_all_groups():
    groups = _okta_get('/api/v1/groups')
    return [[g.get('id'), g.get('profile', {}).get('name')] for g in groups]


def get_all_unrelated_to_user_groups(user_id):
    all_groups = get_all_groups()
    user_groups = get_group_by_user_id(user_id)
    user_group_ids = [g[0] for g in user_groups]
    return [g for g in all_groups if g[0] not in user_group_ids]


def add_user(values):
    first, last, email, password = values[0], values[1], values[2], values[3]
    body = {
        'profile': {
            'firstName': first,
            'lastName': last,
            'email': email,
            'login': email,
            'displayName': f"{first} {last}"
        },
        'credentials': {
            'password': {'value': password}
        }
    }
    resp = _okta_post('/api/v1/users?activate=true', json_body=body)
    if resp.status_code in (200, 201):
        return resp.json().get('id')
    resp.raise_for_status()


def add_group(values):
    name = values[0]
    body = {
        'profile': {
            'name': name,
            'description': name
        }
    }
    resp = _okta_post('/api/v1/groups', json_body=body)
    if resp.status_code in (200, 201):
        return resp.json().get('id')
    resp.raise_for_status()


def add_to_user(user_id, group_id):
    resp = _okta_post(f'/api/v1/groups/{group_id}/users', json_body={'id': user_id})
    return resp.status_code in (200, 204)


def remove_from_user(user_id, group_id):
    resp = _okta_delete(f'/api/v1/groups/{group_id}/users/{user_id}')
    return resp.status_code in (200, 204)


def delete_user(user_id):
    _okta_post(f'/api/v1/users/{user_id}/lifecycle/deactivate')
    resp = _okta_delete(f'/api/v1/users/{user_id}')
    return resp.status_code in (200, 204)


def delete_group(group_id):
    resp = _okta_delete(f'/api/v1/groups/{group_id}')
    return resp.status_code in (200, 204)


def get_user_by_email(user_email):
    resp = _okta_get(f'/api/v1/users?search=profile.login eq "{user_email}"')
    users = resp.json() if resp else []
    return users[0] if users else None


def authenticate_user(username, password):
    """Authenticate user credentials against Okta using authn API"""
    try:
        url = urljoin(OKTA_DOMAIN, '/api/v1/authn')
        payload = {
            'username': username,
            'password': password
        }
        resp = requests.post(url, json=payload, timeout=10)
        return resp.status_code == 200
    except requests.exceptions.RequestException:
        return False
