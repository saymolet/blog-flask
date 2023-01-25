from flask_login import UserMixin, login_user, LoginManager, current_user, logout_user
from flask import Flask, render_template, redirect, url_for, abort, flash, request
from werkzeug.security import generate_password_hash, check_password_hash
from forms import CreatePostForm, CreateUserForm, LoginFrom, CommentForm
from werkzeug.exceptions import HTTPException
from sqlalchemy.orm import relationship
from flask_sqlalchemy import SQLAlchemy
from flask_bootstrap import Bootstrap
from flask_ckeditor import CKEditor
from flask_gravatar import Gravatar
from functools import wraps
import datetime
import os

login_manager = LoginManager()

app = Flask(__name__)
app.config['SECRET_KEY'] = "DMLKSlk882NDJKNSJ388AN"
ckeditor = CKEditor(app)
Bootstrap(app)

# CONNECT TO DB
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///posts.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

login_manager.init_app(app)

gravatar = Gravatar(app,
                    size=100,
                    rating='g',
                    default='identicon',
                    force_default=False,
                    force_lower=False,
                    use_ssl=False,
                    base_url=None)


# CONFIGURE TABLE
class User(UserMixin, db.Model):
    __tablename__ = "users" # noqa
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(100), unique=True)
    name = db.Column(db.String(1000))
    password = db.Column(db.String(200))
    posts = relationship("BlogPost", back_populates="author")
    comments = relationship("Comment", back_populates="comment_author")


class BlogPost(db.Model):
    __tablename__ = "blog_posts"
    id = db.Column(db.Integer, primary_key=True)
    author_id = db.Column(db.Integer, db.ForeignKey("users.id"))
    title = db.Column(db.String(250), unique=True, nullable=False)
    subtitle = db.Column(db.String(250), nullable=False)
    date = db.Column(db.String(250), nullable=False)
    body = db.Column(db.Text, nullable=False)
    img_url = db.Column(db.String(250), nullable=False)
    author = relationship("User", back_populates="posts")
    comments = relationship("Comment", back_populates="parent_post")


class Comment(db.Model):
    __tablename__ = "comments"
    id = db.Column(db.Integer, primary_key=True)
    author_id = db.Column(db.Integer, db.ForeignKey("users.id"))
    post_id = db.Column(db.Integer, db.ForeignKey("blog_posts.id"))
    text = db.Column(db.Text, nullable=False)
    # "users.id" The users refers to the tablename of the Users class.
    # "comments" refers to the comments property in the User class.
    parent_post = relationship("BlogPost", back_populates="comments")
    comment_author = relationship("User", back_populates="comments")


with app.app_context():
    db.create_all()


def admin_only(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if current_user.is_anonymous is False and current_user.id == 1:
            return f(*args, **kwargs)
        else:
            return abort(403)
    return decorated_function


@app.route('/')
def get_all_posts():
    posts = BlogPost.query.all()
    return render_template("index.html", all_posts=posts)


@app.route("/post/<int:post_id>", methods=['POST', 'GET'])
def show_post(post_id):
    requested_post = BlogPost.query.get(post_id)
    comment_form = CommentForm()
    if not requested_post:
        return abort(404)

    if comment_form.validate_on_submit():
        if not current_user.is_authenticated:
            flash("You need to login or register to comment!", "warning")
            return redirect(url_for('login'))
        new_comment = Comment(
            comment_author=current_user,
            parent_post=requested_post,
            text=comment_form.body.data
        )
        db.session.add(new_comment)
        db.session.commit()
        return redirect(url_for('show_post', post_id=post_id))

    all_comments = Comment.query.filter_by(post_id=post_id).all()
    return render_template("post.html", post=requested_post, comment_form=comment_form, all_comments=all_comments)


@app.route("/about")
def about():
    return render_template("about.html")


@app.route("/contact")
def contact():
    return render_template("contact.html")


@app.route("/edit_post/<int:post_id>", methods=["GET", "POST"])
@admin_only
def edit_post(post_id):
    post = BlogPost.query.get(post_id)

    if not post:
        return abort(404)

    edit_form = CreatePostForm(
        title=post.title,
        subtitle=post.subtitle,
        img_url=post.img_url,
        author=post.author,
        body=post.body,
    )

    if edit_form.validate_on_submit():
        # Populate all the changed data to post object entry in DB
        edit_form.populate_obj(post)
        db.session.commit()
        return render_template("post.html", post=post)

    return render_template("make-post.html", form=edit_form, is_edit=True)


@app.route("/new_post", methods=['POST', 'GET'])
@admin_only
def new_post():
    form = CreatePostForm()
    if form.validate_on_submit():
        new_blog_post = BlogPost(
            title=form.title.data,
            subtitle=form.subtitle.data,
            body=form.body.data,
            author=current_user,
            img_url=form.img_url.data,
            date=datetime.datetime.now().strftime("%B %d, %Y")
        )
        db.session.add(new_blog_post)
        db.session.commit()
        return redirect(url_for('get_all_posts'))
    return render_template("make-post.html", form=form)


@app.route('/delete_post/<int:post_id>')
@admin_only
def delete_post(post_id):
    post_to_delete = BlogPost.query.get(post_id)

    if not post_to_delete:
        return abort(404)

    comments_delete = Comment.query.filter_by(post_id=post_id).all()
    for comment in comments_delete:
        db.session.delete(comment)
    db.session.delete(post_to_delete)

    # update all comments post_id to reflect its position
    comments = Comment.query.all()
    for i, comment in enumerate(comments):
        comment.post_id = i + 1

    # update all posts id to reflect its position
    posts = BlogPost.query.all()
    for i, post in enumerate(posts):
        post.id = i + 1
    db.session.commit()
    return redirect(url_for("get_all_posts"))


@app.route('/register', methods=['POST', 'GET'])
def register():
    form = CreateUserForm()
    if form.validate_on_submit():
        name = form.name.data
        email = form.email.data
        password = form.password.data

        if User.query.filter_by(email=email).first() is not None:
            flash("You've already signed in with that email, log in instead!", "warning")
            return redirect(url_for('login'))

        hash_and_salted_password = generate_password_hash(
            password,
            method='pbkdf2:sha256',
            salt_length=8
        )

        new_user = User(
            name=name,
            email=email,
            password=hash_and_salted_password,
        )
        db.session.add(new_user)
        db.session.commit()
        login_user(new_user)
        return redirect(url_for('get_all_posts'))

    return render_template("register.html", form=form)


@app.route('/login', methods=['GET', 'POST'])
def login():
    form = LoginFrom()

    if request.method != "POST":
        return render_template("login.html", form=form)

    user = User.query.filter_by(email=form.email.data).first()
    if not user:
        flash("Invalid Email!", "danger")
        return redirect(url_for('login'))

    if check_password_hash(user.password, form.password.data):
        login_user(user)
        return redirect(url_for('get_all_posts'))
    else:
        flash("Invalid Password!", "danger")
        return redirect(url_for('login'))


@app.route('/logout')
def logout():
    logout_user()
    return redirect(url_for('get_all_posts'))


# error handling for all http errors
@app.errorhandler(HTTPException)
def page_not_found(e):
    return render_template('error.html', error=e.code, message=e.description), e.code


@login_manager.user_loader
def load_user(user_id):
    return User.query.get(user_id)


if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000, debug=True)
