from flask import Flask, render_template, request, redirect, session
import okta_handler as entra_handler
import os
from dotenv import load_dotenv
load_dotenv()

class Page:
    def __init__(self, name, headers, addfields, db):
        self.name = name
        self.addname = name.lower()
        self.headers = headers.copy()
        self.addfields = addfields.copy()
        self.db = db
EmPage = Page("Employee", ['ID', 'Name', 'Department', 'E-mail', 'Groups', "Delete"], ['First Name', 'Last Name', 'E-mail', 'Password', "Repeat Password"], "users")
GrPage = Page("Group", ["ID", "Name", "Members", "Delete"], ["Group Name"], "user_groups")

app = Flask(__name__);

app.secret_key= os.getenv("SECRET_KEY")


@app.before_request
def catch_all_existing_routes():
    if 'username' not in session and request.endpoint not in ['login', 'static'] and request.endpoint is not None:
        return redirect("/login")
    
@app.errorhandler(404)
def page_not_found(e):
    return render_template("page_not_found.html"), 404

@app.route("/")
def index():
    return redirect("/employees")

@app.route("/employees")
def employees():
    result = entra_handler.get_all_users_info()
    for row in result:
        user_id = row[0]
        groups = entra_handler.get_group_by_user_id(user_id)
        groups = [group[1] for group in groups] if groups else ["No Groups"]
        row.append(groups if groups else ["No Groups"])
        row.append("/delete/employee/" + user_id)

    if result is None:
        return render_template("index.html", headers = EmPage.headers, name = EmPage.name, rows = [], addname = EmPage.addname, delete_column=5)
    
    return render_template("index.html", headers = EmPage.headers, name = EmPage.name, addname = EmPage.addname, rows = result, delete_column=5)


@app.route("/groups")
def groups():
    result = entra_handler.get_all_groups()
    for row in result:
        group_id = row[0]
        members = entra_handler.get_group_members(group_id)
        members = [member[1] for member in members] 
        row.append(members if members else ["No Members"])
        row.append("/delete/group/" + group_id)
    if result is None:
        return render_template("index.html", headers = GrPage.headers, name = GrPage.name, rows = [], addname = GrPage.addname, delete_column=3)
    return render_template("index.html", headers = GrPage.headers, name = GrPage.name, addname = GrPage.addname, rows = result, delete_column=3)


@app.route("/add_employee")
def add_employee():
    return render_template("add_new.html", addfields = EmPage.addfields, name = EmPage.name, url= EmPage.addname, passfields=[3, 4])

@app.route("/add_group")
def add_group():
    return render_template("add_new.html", addfields = GrPage.addfields, name = GrPage.name, url= GrPage.addname)

@app.route("/add/<name>", methods=['POST'])
def add_new(name):
    values = [request.form[field] for field in request.form]
    entra_handler.add_user(values) if name == "employee" else entra_handler.add_group(values)
    return redirect("/")

@app.route("/add_to_user/<name>/<string:id>")
def add_to_user(name, id):
    if name == "group":
        headings_no_link = entra_handler.get_all_unrelated_to_user_groups(id)
        headings_link = entra_handler.get_group_by_user_id(id)
        return render_template("add_attribute_to_user.html", headings_no_link=headings_no_link, headings_link = headings_link, id = id, url = "/update_user/" + name + "/")
    else:
        return "Invalid name", 400
@app.route("/update_user/group/<string:id>", methods=['POST'])
def update_user_membership(id):
    selected_group_ids = request.form.getlist('group_ids')
    selected_group_ids = list(map(str, selected_group_ids))

    current_group_ids = [row[0] for row in entra_handler.get_group_by_user_id(id)]


    to_add = list(set(selected_group_ids) - set(current_group_ids))
    to_remove = list(set(current_group_ids) - set(selected_group_ids))


    for group_id in to_add:
        entra_handler.add_to_user(id, group_id)

    for group_id in to_remove:
        entra_handler.remove_from_user(id, group_id)
    return redirect('/')

@app.route("/delete/<name>/<string:id>")
def delete_entry(name, id):
    if name == "employee":
        entra_handler.delete_user(id)
    elif name == "group":
        entra_handler.delete_group(id)
    else:
        return "Invalid name", 400
    return redirect("/")

@app.route("/login", methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['Username']
        password = request.form['Password']
        # Validate credentials against Okta
        if entra_handler.authenticate_user(username, password):
            session['username'] = username
            return redirect('/')
        else:
            return "Invalid credentials", 401
    return render_template("login.html", loginfields=["Username", "Password"], url="/login", passfields=[1])

@app.route("/logout")
def logout():
    session.pop('username', None)
    return redirect("/login")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)