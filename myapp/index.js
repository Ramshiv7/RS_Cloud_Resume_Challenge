async function counter() {
    let response = await fetch(
        "https://0sk92g2h34.execute-api.us-east-1.amazonaws.com/myStage/counter"
    );
    let data = await response.json();
    document.getElementById("count").innerText = data.count
}
counter();