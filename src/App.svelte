<script>
    import Table from "./Table.svelte";
    import Graph from "./Graph.svelte";

    let sampleGraphInput = [
        {   name : ">A/Brevig Mission/1/1918",
            x: 1.6926632550248393,
            y: -0.7288658070162048,
        },
        { name: ">A/Shanghai/202/1957 ",
            x: 0.41759304340283687,
            y: 1.2213080481077907,
        },
        {name: ">A/Hong Kong/1-10-MA21-1/1968",
            x: 3.0573445551138354,
            y: 0.5346156818757907,
        },
        {name: ">A/Texas/44151841/2009",
            x: 3.9923269590698345,
            y: -0.31801450819521004,
        },
        {name: ">A/equine/Miami/1/1963",
            x: 0.2207416054528371,
            y: 1.8059139500347925,
        },
        {name: ">A/canine/New York/115809/2005",
            x: 4.6997483881318365,
            y: 0.5721253723817918,
        },
        {name: ">A/canine/Guangdong/1/2006",
            x: 2.223918940054842,
            y: -0.6601918990612051,
        },
        {name: ">A/swine/USA/1976/1931",
            x: 0.9633469170268413,
            y: -1.070428837884209,
        },
        {name: ">A/swine/Belgium/1/79",
            x: -0.7435014212281634,
            y: 0.8170337061927884,
        },
        {name: ">A/swine/Ontario/33853/2005",
            x: 3.437834915106846,
            y: 0.01269440680979625,
        },
        {name: ">A/swine/Iowa/MT_12_07_11_2_26/2011",
            x: 3.0065693314278334,
            y: -1.0392809556862064,
        },
        {name: ">A/swine/Oklahoma/02722/2009",
            x: 3.4963447822888356,
            y: -0.45677648266320797,
        },
        {name: ">A/swine/Netherlands/12/1985",
            x: 0.6333327690578412,
            y: -0.5304044986552063,
        },
    ]
    

    let HAfile;
    let NAfile;
    let NPfile;
    let PAfile;
    let PB1file;
    let PB2file;
    let Mfile;
    let NSfile;
    let runtype = "CDS";
    async function submit() {
        let jobid;

        const getUploadURLResponse = await fetch(
            "https://7dw7gs4iynbh5sygciwg5f4wky0vepdw.lambda-url.us-east-1.on.aws/?" +
                "runtype=" +
                runtype
        );
        const getUploadURLResponseJson = await getUploadURLResponse.json();
        if (!getUploadURLResponse.ok) {
            return new Error("Server Error: 1");
        }
        if (
            !"status" in getUploadURLResponseJson ||
            !"url_responses" in getUploadURLResponseJson ||
            !"job_id" in getUploadURLResponseJson
        ) {
            return new Error("Server Error: 2");
        }
        if (
            !getUploadURLResponseJson["status"] == "success" ||
            !"message" in getUploadURLResponseJson
        ) {
            return new Error(getUploadURLResponseJson["message"]);
        }
        const uploadUrlsInfo = getUploadURLResponseJson["url_responses"];
        jobid = getUploadURLResponseJson["job_id"];
        let successUpload = 0;

        for (const seqType in uploadUrlsInfo) {
            let mfile;
            switch (seqType) {
                case "HA":
                    mfile = HAfile;
                    break;
                case "NA":
                    mfile = NAfile;
                    break;
                case "NP":
                    mfile = NPfile;
                    break;
                case "PA":
                    mfile = PAfile;
                    break;
                case "PB1":
                    mfile = PB1file;
                    break;
                case "PB2":
                    mfile = PB2file;
                    break;
                case "M":
                case "M1":
                    mfile = Mfile;
                    break;
                case "NS":
                case "NS1":
                    mfile = NSfile;
                    break;
                default:
                    return new Error("Server Error: 3");
            }

            const formData = new FormData();
            Object.keys(uploadUrlsInfo[seqType].fields).forEach((key) => {
                formData.append(key, uploadUrlsInfo[seqType].fields[key]);
            });
            formData.append("file", mfile[0]);
            console.log(formData);
            let retry = 0;
            do {
                const uploadRes = await fetch(uploadUrlsInfo[seqType].url, {
                    method: "POST",
                    mode: "cors",
                    body: formData,
                });
                if (uploadRes.ok) {
                    successUpload++;
                    console.log(`uploaded ${seqType} file successfully.`);
                    break;
                } else {
                    retry++;
                    console.warn(
                        `uploaded ${seqType} file failed, retry count: ${retry}`
                    );
                }
            } while (retry <= 3);
            if (retry > 3) {
                return new Error("Server Error: 4");
            }
        }

        if (successUpload == 8) {
            const finishUploadResponse = await fetch(
                "https://duz5hhucocqrcvc4ub6ukcu26i0zrczv.lambda-url.us-east-1.on.aws/?jobid=" +
                    jobid +
                    "&runtype=" +
                    runtype
            );
            const finishUploadResponseJson = await finishUploadResponse.json();
            if (!finishUploadResponse.ok) {
                return new Error("Server Error: 5");
            }
            if (
                !"status" in finishUploadResponseJson ||
                !finishUploadResponseJson["status"] == "success"
            ) {
                if (
                    "message" in finishUploadResponseJson &&
                    finishUploadResponseJson["message"]
                ) {
                    return new Error(finishUploadResponseJson["message"]);
                }
                return new Error("Server Error: 6");
            }

            let errorCount = 0;
            while (true) {
                await new Promise((r) => setTimeout(r, 5000));
                const getResultResponse = await fetch(
                    `https://3kksz4rczce67rboxnvpylwlxy0vuhtn.lambda-url.us-east-1.on.aws/?jobid=${jobid}`
                );
                const getResultResponseJson = await getResultResponse.json();
                if (!getResultResponse.ok) {
                    errorCount++;
                    if (errorCount >= 100) {
                        return new Error("Server Error: 6");
                    }
                    continue;
                }
                if (
                    !"status" in getResultResponseJson ||
                    !"message" in getResultResponseJson
                ) {
                    return new Error("Server Error: 7");
                }

                if (getResultResponseJson["status"] == "error") {
                    return new Error(getResultResponseJson["message"]);
                }
                console.log(getResultResponseJson);
                if (
                    getResultResponseJson["status"] == "success" &&
                    "message" in getResultResponseJson &&
                    "status" in getResultResponseJson["message"] &&
                    "graph_status" in getResultResponseJson["message"]
                ) {
                    if (
                        getResultResponseJson["message"]["status"]["S"] ==
                            "finished" &&
                        getResultResponseJson["message"]["graph_status"]["S"] ==
                            "finished"
                    ) {
                        console.log(getResultResponseJson["message"]);
                        let resultText =
                            getResultResponseJson["message"]["result"]["S"];
                        let resultTableData = resultText
                            .split(",")
                            .map((text) => {
                                let temp = text.split(":");
                                return {
                                    "Sequence name": temp[0],
                                    "Prediction (sustained transmission: +1, sporadic infection: -1)": temp[1],
                                };
                            });
                        let graphResultJson =
                            JSON.parse(getResultResponseJson["message"]["graph_result"]["S"]);
                        let graphFinalResult = []
                        for (let key in graphResultJson) {
                            graphFinalResult.push({
                                name: key,
                                x: graphResultJson[key].x,
                                y: graphResultJson[key].y,
                            })
                        }
                        console.log(graphFinalResult)
                        return [
                            resultTableData,
                            graphFinalResult
                        ];
                    } else {
                        console.log(getResultResponseJson["message"]);
                    }
                } else {
                    return new Error("Server Error 8");
                }
            }
        } else {
            console.error(
                `amount of uploaded files not equal to 8, current amount: ${successUpload}`
            );
            return new Error("Server Error: 9");
        }
    }
    let promise;
    function handleSubmit() {
        if (
            HAfile?.[0] &&
            NAfile?.[0] &&
            NPfile?.[0] &&
            PAfile?.[0] &&
            PB1file?.[0] &&
            PB2file?.[0] &&
            Mfile?.[0] &&
            NSfile?.[0]
        ) {
            promise = submit();
        }
    }
</script>

<svelte:head>
    <title>Prediction for sustained transmission of influenza A viruses in mammals</title>
	<html lang="en" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
          padding: 0px;
        }
      </style>
</svelte:head>

<div class="main">
    <h1><center>Prediction for sustained transmission of influenza A viruses in mammals</center></h1>
    <p>
        Upload eight protein coding regions (HA, NA, NP, PA, PB1, PB2, M1 and NS1) or eight nucleotide segments (HA, NA, NP, PA, PB1, PB2, M and NS) to assess the risk of sustained transmission in a mammalian host for a set of avian or recently zoonotic influenza A viruses.
    </p>
    <h2>Choose sequence type:(Protein coding region or Neucleotide segments)</h2>
    <div class="row">
        <label class="runtypebutton">
            <input
                type="radio"
                bind:group={runtype}
                name="runtype"
                value="CDS"
            />
            Protein coding region
        </label>
        <label>
            <input
                type="radio"
                bind:group={runtype}
                name="runtype"
                value="WGS"
            />
            Whole genome segments
        </label>
    </div>
    <h2>Select your FASTA sequences</h2>
    <label>
        HA:
        <input type="file" accept=".fasta" bind:files={HAfile} />
    </label>
    <label>
        NA:
        <input type="file" accept=".fasta" bind:files={NAfile} />
    </label>
    <label>
        NP:
        <input type="file" accept=".fasta" bind:files={NPfile} />
    </label>
    <label>
        PA:
        <input type="file" accept=".fasta" bind:files={PAfile} />
    </label>
    <label>
        PB1:
        <input type="file" accept=".fasta" bind:files={PB1file} />
    </label>
    <label>
        PB2:
        <input type="file" accept=".fasta" bind:files={PB2file} />
    </label>
    <label>
        {runtype == "CDS" ? "M1" : "M"}:
        <input type="file" accept=".fasta" bind:files={Mfile} />
    </label>
    <label>
        {runtype == "CDS" ? "NS1" : "NS"}:
        <input type="file" accept=".fasta" bind:files={NSfile} />
    </label>
    <p>
        * Sequence names of the eight protein coding regions or nucleotide segments should be the same for each influenza A virus.
    </p>
    <button on:click={handleSubmit}>Submit</button>
    {#await promise}
        <p>File is uploading and calculating results...</p>
    {:then res}
        {#if res}
            <h2>Success, here is the result:</h2>
            <Table tableData={res[0]} style="blueTable" />
            <h2>2D projection by linear discriminant analysis</h2>
            <div class="graphContainer">
                <Graph data={res[1]} />
                <img class="legend" src="./legends.PNG" alt="Graph legends"/>
            </div>
            <p>Positions of the tested IAVs (brown points) are shown on the distributions of avian and sporadic mammalian IAVs (gray zones), and persistent mammalian lineages (red zones). Hover your mouse on the points to see their sequence names. The earliest sequences in persistent mammalian lineages are also highlighted.
            </p>
        {/if}
    {:catch error}
        <p>Error occured: {error.message}</p>
    {/await}
</div>

<style>
    .main {
        width: auto;
        height: auto;
        padding: 32px;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
    }

    div.row {
        display: flex;
        flex-direction: row;
    }

    label.runtypebutton {
        padding-left: 16px;
        padding-right: 16px;
    }

    div.graphContainer {
        display: flex;
        flex-direction: row;
        justify-content: center;
        align-items: center;
    }

    img.legend {
        width: 482px;
        height: 280px;
    }

    p {
        padding-left: 128px;
        padding-right: 128px;
    }
</style>
