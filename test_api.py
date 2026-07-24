import requests

url = "https://ai-story-mo52.onrender.com/api/v1/personas"
res = requests.get(url)
print("Personas GET:", res.status_code, res.text)

# Let's get stories to find a character
url = "https://ai-story-mo52.onrender.com/api/v1/stories"
res = requests.get(url)
print("Stories GET:", res.status_code, res.text)
