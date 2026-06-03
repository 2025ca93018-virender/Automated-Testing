import os
import requests
from dotenv import load_dotenv
from flask import Flask, render_template, request, redirect, url_for, session, flash

load_dotenv()

app = Flask(__name__)
app.secret_key = os.environ.get(
    "FLASK_SECRET_KEY",
    "dev-secret-key-change-in-prod"
)

# Demo user store (academic demo only)
USERS = {
    "admin": "admin123"
}

HF_API_TOKEN = os.environ.get("HF_API_TOKEN", "")

# Hugging Face Router Chat Completions API
HF_MODEL_URL = "https://router.huggingface.co/v1/chat/completions"


@app.route("/")
def index():
    return redirect(url_for("login"))


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form.get("username", "").strip()
        password = request.form.get("password", "").strip()

        if username in USERS and USERS[username] == password:
            session["user"] = username
            return redirect(url_for("qa"))

        flash("Invalid credentials. Please try again.")

    return render_template("login.html")


@app.route("/qa", methods=["GET", "POST"])
def qa():
    if "user" not in session:
        return redirect(url_for("login"))

    answer = None
    question = ""

    if request.method == "POST":
        question = request.form.get("question", "").strip()

        if question:
            answer = ask_llm(question)

    return render_template(
        "qa.html",
        username=session["user"],
        question=question,
        answer=answer
    )


@app.route("/logout")
def logout():
    session.pop("user", None)
    return redirect(url_for("login"))


def ask_llm(question: str) -> str:
    if not HF_API_TOKEN:
        return "HF_API_TOKEN environment variable is not configured."

    try:
        payload = {
            "model": "meta-llama/Llama-3.1-8B-Instruct",
            "messages": [
                {
                    "role": "user",
                    "content": question
                }
            ],
            "max_tokens": 200
        }

        response = requests.post(
            HF_MODEL_URL,
            headers={
                "Authorization": f"Bearer {HF_API_TOKEN}",
                "Content-Type": "application/json"
            },
            json=payload,
            timeout=30
        )

        print("===================================")
        print("Status Code:", response.status_code)
        print("Response Body:", response.text)
        print("===================================")

        response.raise_for_status()

        data = response.json()

        return data["choices"][0]["message"]["content"]

    except requests.exceptions.RequestException as exc:
        return f"Error contacting LLM: {exc}"

    except Exception as exc:
        return f"Unexpected error: {str(exc)}"


if __name__ == "__main__":
    print("Starting Flask App...")
    print(
        "HF Token Loaded:",
        "YES" if HF_API_TOKEN else "NO"
    )
    app.run(host="0.0.0.0", port=5000)