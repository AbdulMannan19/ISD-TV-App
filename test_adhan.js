const makeAdhanAPICall = async () => {
    const today = new Date();
    const day = today.getDate();
    const month = today.getMonth() + 1;
    const year = today.getFullYear();
    const date = `${day < 10 ? '0' + day : day}-${month < 10 ? '0' + month : month}-${year}`;
    const coordinates = "?latitude=33.201662695006874&longitude=-97.14494994434574&method=2";
    console.log("Date being recieved is: " + date);

    // User's URL
    const apiUrlUser = `https://api.aladhan.com/v1/timings/date=${date}${coordinates}`;

    // My URL
    const apiUrlMy = `https://api.aladhan.com/v1/timings/${date}?latitude=33.201662695006874&longitude=-97.14494994434574&method=2`;

    try {
        console.log("Fetching User URL:", apiUrlUser);
        let response = await fetch(apiUrlUser);
        let data = await response.json();
        console.log("USER URL Asr:", data.data.timings.Asr);

        console.log("Fetching My URL:", apiUrlMy);
        response = await fetch(apiUrlMy);
        data = await response.json();
        console.log("MY URL Asr:", data.data.timings.Asr);

        console.log("\nFull Output of My URL timings:");
        console.log(JSON.stringify(data.data.timings, null, 2));
    } catch (e) {
        console.error("API Error:", e);
    }
};

makeAdhanAPICall();
