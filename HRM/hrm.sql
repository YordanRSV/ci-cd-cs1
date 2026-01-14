create table users (
id int not null auto_increment primary key, 
first_name varchar(255) not null, 
last_name varchar(255) not null, 
department_name varchar(255) not null, 
email varchar(255) not null
);

create table roles (
id int not null auto_increment primary key,
role_name varchar(255) not null
);

create table user_groups (
id int not null auto_increment primary key, 
group_name varchar(255) not null
);

CREATE TABLE users_roles (
id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
user_id INT,
role_id INT,
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE 
users_groups (
id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
user_id INT,     
group_id INT,     
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
FOREIGN KEY (group_id) REFERENCES user_groups(id) ON DELETE CASCADE ON UPDATE CASCADE 
);
