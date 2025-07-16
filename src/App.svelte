<script>
  import Table from "./Table.svelte";
  import Graph from "./Graph.svelte";

  // settings
  const fetchInterval = 2 * 1000; // get result fetch interval in milliseconds
  const maxFetch = 100; // max get result fetch until error
  const maxErrorFetch = 5; // max fetch for getting error
  const tableColNameSeq = "Sequence name";
  const tableColNameGenomicGCContent = "Genomic GC content (%)";
  const tableColNamePrediction = "Prediction";

  let inputFiles = {
    PB2: null,
    PB1: null,
    PA: null,
    HA: null,
    NP: null,
    NA: null,
    M: null, // stores M or M1 based on runtype
    NS: null, // stores NS or NS1 based on runtype
  };
  let input = {
    PB2: null,
    PB1: null,
    PA: null,
    HA: null,
    NP: null,
    NA: null,
    M: null, // stores M or M1 based on runtype
    NS: null, // stores NS or NS1 based on runtype
  };
  let runtype = "CDS"; // "CDS" or "WGS"
  let promise = null;
  let isSubmitted = false;

  const checkResponse = (response, responseJson, expectedKeys) => {
    if (!response.ok) {
      console.error(`JSON return code not ok: ${response.status}`);
      throw new Error("Error: Cannot connect to the server.");
    }
    if ("error" in responseJson) {
      console.error("error key appears in response JSON");
      console.error(responseJson.error);
      throw new Error(responseJson.error);
    }
    for (const key of expectedKeys) {
      if (key in responseJson === false) {
        console.error(`reponse object do not have the expected key: ${key}`);
        console.error(`expectedKeys: ${expectedKeys}`);
        throw new Error(`Error: Unexpected error occured`);
      }
    }
  };

  async function submit() {
    isSubmitted = true;
    const getUploadURLResponse = await fetch(
      `https://p67eisaxrntpxhtqjt2f4bhsou0fnmhm.lambda-url.us-east-1.on.aws/?runtype=${runtype}`,
      {
        method: "POST",
        mode: "cors",
      }
    );
    const getUploadURLResponseJson = await getUploadURLResponse.json();
    checkResponse(getUploadURLResponse, getUploadURLResponseJson, [
      "url_responses",
      "job_id",
    ]);
    const uploadUrlsInfo = getUploadURLResponseJson["url_responses"];
    const jobid = getUploadURLResponseJson["job_id"];
    let successUpload = 0;

    for (const [inputType, inputFile] of Object.entries(inputFiles)) {
      let mInputType = inputType;
      if (runtype === "CDS" && (inputType === "M" || inputType === "NS")) {
        mInputType = mInputType + "1";
      }
      const formData = new FormData();
      Object.keys(uploadUrlsInfo[mInputType].fields).forEach((key) => {
        formData.append(key, uploadUrlsInfo[mInputType].fields[key]);
      });
      formData.append("file", inputFile[0]);
      let retry = 0;
      do {
        const uploadRes = await fetch(uploadUrlsInfo[mInputType].url, {
          method: "POST",
          mode: "cors",
          body: formData,
        });
        if (uploadRes.ok) {
          successUpload++;
          break;
        } else {
          retry++;
          console.warn(
            `uploaded ${mInputType} file failed, retry count: ${retry}`
          );
          console.warn(uploadRes?.body);
        }
      } while (retry <= 3);
      if (retry > 3) {
        console.error(`Reached max retry during uploading ${inputFile}`);
        throw new Error("Cannot upload files to server");
      }
    }

    if (successUpload == 8) {
      const finishUploadResponse = await fetch(
        `https://6knl3dtwkvvngczchnvtubzkje0msjxf.lambda-url.us-east-1.on.aws/?jobid=${jobid}&runtype=${runtype}`,
        {
          method: "POST",
          mode: "cors",
        }
      );
      const finishUploadResponseJson = await finishUploadResponse.json();
      checkResponse(finishUploadResponse, finishUploadResponseJson, [
        "success",
      ]);

      let fetchCount = 0;
      let errorFetchCount = 0;
      while (true) {
        await new Promise((r) => setTimeout(r, fetchInterval));
        const getResultResponse = await fetch(
          `https://5nyo63rxfytss7xystvqnqasaq0looqo.lambda-url.us-east-1.on.aws/?jobid=${jobid}`
        );
        const getResultResponseJson = await getResultResponse.json();
        try {
          checkResponse(getResultResponse, getResultResponseJson, [
            "status",
            "graph_status",
          ]);
        } catch (e) {
          if (errorFetchCount > maxErrorFetch) {
            console.error(
              `ErrorFetchCount exceeds ${maxErrorFetch}, ${getResultResponseJson}`
            );
            throw new Error("cannot connect to the server");
          }
          errorFetchCount++;
          console.warn(
            `Cannot connect to the server, error fetch count: ${errorFetchCount}`
          );
          continue;
        }
        if (
          getResultResponseJson["status"]["S"] === "finished" &&
          getResultResponseJson["graph_status"]["S"] === "finished" &&
          "result" in getResultResponseJson &&
          "graph_result" in getResultResponseJson &&
          "total_gc_content" in getResultResponseJson
        ) {
          const resultText = getResultResponseJson["result"]["S"];
          let resultTextLines = resultText.split("\n");
          let transformedResultText = [];
          let gcContentResult = JSON.parse(
            getResultResponseJson["total_gc_content"]["S"] ?? "{}"
          );
          for (let x = 0; x < resultTextLines.length; x += 2) {
            const gc_content = gcContentResult[resultTextLines[x]];
            transformedResultText = [
              ...transformedResultText,
              {
                [tableColNameSeq]: resultTextLines[x],
                [tableColNameGenomicGCContent]: gc_content || 0,
                [tableColNamePrediction]: resultTextLines[x + 1],
              },
            ];
          }
          console.log(transformedResultText);

          let graphResultJson = JSON.parse(
            getResultResponseJson["graph_result"]["S"] ?? "{}"
          );
          let graphFinalResult = [];
          for (let key in graphResultJson) {
            graphFinalResult.push({
              name: key,
              x: graphResultJson[key].x,
              y: graphResultJson[key].y,
            });
          }
          return [transformedResultText, graphFinalResult];
        } else {
          fetchCount++;
          if (fetchCount > maxFetch) {
            console.error(`fetchCount exceeds maxFetch(${maxFetch})`);
            throw new Error("Server Error");
          }
        }
      }
    } else {
      console.error(
        `amount of uploaded files not equal to 8, current amount: ${successUpload}`
      );
      throw new Error("Unexpected error occured.");
    }
  }

  const loadDemoDataAndRun = async () => {
    runtype = "CDS";
    for (const [inputType, _] of Object.entries(inputFiles)) {
      let cdsInputType = inputType;
      if (runtype === "CDS" && (inputType === "M" || inputType === "NS")) {
        cdsInputType = cdsInputType + "1";
      }
      const filename = `./demo-inputs/${cdsInputType}_nt_mink.pal2nal`;
      let response = await fetch(`./${filename}`);
      let data = await response.blob();
      let metadata = { type: "" };
      inputFiles[inputType] = [new File([data], filename, metadata)];
    }
    handleSubmit();
  };

  const handleSubmit = () => {
    for (const [_, inputFile] of Object.entries(inputFiles)) {
      if (inputFile?.length === 0) return;
    }
    promise = submit();
  };

  const handleRunDemo = () => {
    promise = loadDemoDataAndRun();
  };

  const handleReset = () => {
    promise = null;
    isSubmitted = false;
    for (const [inputType, _] of Object.entries(inputFiles)) {
      inputFiles[inputType] = null;
    }
    for (const [inputType, inputFeild] of Object.entries(input)) {
      inputFeild.value = "";
    }
  };
</script>

<svelte:head>
  <title
    >Risk assessment of sustained mammalian transmission of influenza A viruses</title
  >
  <html lang="en" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <style>
    body {
      padding: 0px;
    }
  </style>
</svelte:head>

<div class="main">
  <h2>
    Risk assessment of sustained mammalian transmission of influenza A viruses
  </h2>

  <div class="intro-section">
    <div class="graphContainer">
      <img class="intro_photo" src="./intro.png" alt="Graph introduction" />
      <div class="intro">
        <p>
          Upload eight protein coding regions (HA, NA, NP, PA, PB1, PB2, M1 and
          NS1) or eight nucleotide segments (HA, NA, NP, PA, PB1, PB2, MP and
          NS) to assess the risk of sustained transmission in mammals for avian
          or recently zoonotic influenza A viruses. Details in
          <a href="https://github.com/id-bioinfo/IAV_GCContent" target="_blank"
            >https://github.com/id-bioinfo/IAV_GCContent</a
          >.
        </p>
      </div>
    </div>
  </div>

  <h3>Choose sequence type:</h3>
  <div class="row">
    <label class="runtypebutton">
      <input type="radio" bind:group={runtype} name="runtype" value="CDS" />
      Protein coding region (recommended)
    </label>
    <label class="runtypebutton">
      <input type="radio" bind:group={runtype} name="runtype" value="WGS" />
      Nucleotide segment
    </label>
  </div>

  <h3>Select your FASTA sequences:</h3>
  <div class="inputFileDiv">
    {#each Object.entries(inputFiles) as [inputType, _]}
      <label class="inputFileLabel">
        <p class="inputFileLabelText">
          {inputType === "M"
            ? runtype === "CDS"
              ? "M"
              : "MP"
            : inputType}{#if (inputType === "M" || inputType === "NS") && runtype === "CDS"}1{/if}:
        </p>
        <input
          type="file"
          bind:files={inputFiles[inputType]}
          bind:this={input[inputType]}
          disabled={isSubmitted}
        />
      </label>
    {/each}
  </div>

  <div class="note">
    <strong>Note:</strong> Sequence names of the eight protein coding regions or
    nucleotide segments should be the same for each influenza A virus in the input
    files.
  </div>

  {#if promise === null}
    <div class="row">
      <button on:click={handleSubmit}>Run Analysis</button>
      <button class="demo-button" on:click={handleRunDemo}
        >Run Demo (Mink H5N1 IAVs)</button
      >
    </div>
  {/if}

  {#await promise}
    <div class="loading">Processing your sequences...</div>
  {:then res}
    {#if res}
      <div class="results-section">
        <button class="reset-button" on:click={handleReset}>Reset</button>

        <h3>SVM Prediction Results</h3>
        <Table tableData={res[0]} style="minimal" />
        <div class="prediction-note">
          <strong>Prediction Guide:</strong><br />
          <strong>1</strong> indicates sustained transmission potential in
          mammalian hosts<br />
          <strong>-1</strong> indicates predicted sporadic infection in mammals<br
          /><br />
          The prediction is based on a combination of GC content and CG dinucleotide
          frequencies of eight CDS or segments using our developed SVM model.
        </div>

        <h3>Visualization by 2D projection</h3>
        <div class="graphContainer">
          <Graph data={res[1]} />
          <img class="legend" src="./legends.jpeg" alt="Graph legends" />
        </div>
        <div class="visualization-note">
          <strong>Visualization Guide:</strong><br />
          Positions of the tested IAVs (brown points) are shown on the distributions
          of avian and sporadic mammalian IAVs (gray zones), and persistent mammalian
          lineages (red zones), estimated by linear discriminant analysis. Hover
          your mouse on the points to see their sequence names. The earliest sequences
          in persistent mammalian lineages are also highlighted.
        </div>
      </div>
    {/if}
  {:catch error}
    <div class="results-section">
      <button class="reset-button" on:click={handleReset}>Reset</button>
      <div class="error">
        <strong>Error occurred:</strong><br />
        <pre>{error}</pre>
      </div>
    </div>
  {/await}
</div>

<style>
  :global(body) {
    margin: 0;
    padding: 0;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen,
      Ubuntu, Cantarell, sans-serif;
    background: #f8fafc;
    min-height: 100vh;
    color: #334155;
    line-height: 1.6;
  }

  .main {
    max-width: 1200px;
    margin: 0 auto;
    padding: 40px 20px;
    background: white;
    border-radius: 12px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
    margin-top: 20px;
    margin-bottom: 20px;
  }

  h2 {
    font-size: 2.2rem;
    font-weight: 600;
    color: #1e293b;
    text-align: center;
    margin-bottom: 2rem;
    border-bottom: 1px solid #e2e8f0;
    padding-bottom: 1rem;
  }

  h3 {
    font-size: 1.3rem;
    font-weight: 600;
    color: #475569;
    margin: 2rem 0 1rem 0;
    border-left: 3px solid #64748b;
    padding-left: 1rem;
  }

  .intro-section {
    background: #f8fafc;
    border-radius: 8px;
    padding: 2rem;
    margin: 2rem 0;
    border: 1px solid #e2e8f0;
  }

  div.row {
    display: flex;
    flex-direction: row;
    gap: 1rem;
    flex-wrap: wrap;
    align-items: center;
    margin: 1rem 0;
  }

  div.inputFileDiv {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 1rem;
    padding: 1.5rem;
    background: #f8fafc;
    border-radius: 8px;
    border: 1px solid #e2e8f0;
  }

  label.inputFileLabel {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 0.5rem;
    padding: 1rem;
    background: white;
    border-radius: 6px;
    border: 1px solid #e2e8f0;
    transition: border-color 0.2s ease;
  }

  label.inputFileLabel:hover {
    border-color: #94a3b8;
  }

  p.inputFileLabelText {
    font-weight: 600;
    color: #64748b;
    margin: 0;
    font-size: 0.9rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  input[type="file"] {
    width: 100%;
    padding: 0.5rem;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    font-size: 0.9rem;
    transition: border-color 0.2s ease;
  }

  input[type="file"]:focus {
    outline: none;
    border-color: #64748b;
  }

  input[type="radio"] {
    transform: scale(1.1);
    accent-color: #475569;
  }

  label.runtypebutton {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.75rem 1.5rem;
    background: white;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    cursor: pointer;
    transition: all 0.2s ease;
    font-weight: 500;
  }

  label.runtypebutton:hover {
    border-color: #94a3b8;
    background: #f8fafc;
  }

  label.runtypebutton:has(input:checked) {
    background: #475569;
    color: white;
    border-color: #475569;
  }

  button {
    padding: 0.75rem 2rem;
    background: #475569;
    color: white;
    border: none;
    border-radius: 6px;
    font-size: 1rem;
    font-weight: 500;
    cursor: pointer;
    transition: background-color 0.2s ease;
  }

  button:hover {
    background: #334155;
  }

  .demo-button {
    background: #64748b;
  }

  .demo-button:hover {
    background: #475569;
  }

  .reset-button {
    background: #94a3b8;
    margin-bottom: 1rem;
  }

  .reset-button:hover {
    background: #64748b;
  }

  .loading {
    text-align: center;
    padding: 3rem;
    font-size: 1.1rem;
    color: #64748b;
    font-weight: 500;
  }

  .loading::after {
    content: "";
    display: inline-block;
    width: 18px;
    height: 18px;
    border: 2px solid #e2e8f0;
    border-top: 2px solid #64748b;
    border-radius: 50%;
    animation: spin 1s linear infinite;
    margin-left: 10px;
  }

  @keyframes spin {
    0% {
      transform: rotate(0deg);
    }
    100% {
      transform: rotate(360deg);
    }
  }

  .error {
    background: #fef2f2;
    border: 1px solid #fecaca;
    color: #991b1b;
    padding: 1rem;
    border-radius: 6px;
    margin: 1rem 0;
  }

  .results-section {
    background: white;
    border-radius: 8px;
    padding: 2rem;
    margin: 2rem 0;
    border: 1px solid #e2e8f0;
  }

  div.graphContainer {
    display: flex;
    width: 100%;
    flex-direction: row;
    flex-wrap: wrap;
    justify-content: center;
    align-items: flex-start;
    gap: 2rem;
  }

  img.legend {
    aspect-ratio: 926/631;
    max-height: 447px;
    border-radius: 6px;
    border: 1px solid #e2e8f0;
  }

  img.intro_photo {
    width: 100%;
    max-width: 450px;
    height: auto;
    border-radius: 8px;
    border: 1px solid #e2e8f0;
  }

  div.intro {
    flex: 1;
    min-width: 300px;
    padding: 1rem;
  }

  div.intro p {
    font-size: 1rem;
    line-height: 1.6;
    color: #475569;
    margin: 0;
  }

  div.intro a {
    color: #475569;
    text-decoration: underline;
    font-weight: 500;
  }

  div.intro a:hover {
    color: #334155;
  }

  .note {
    background: #f0f9ff;
    border-left: 3px solid #0ea5e9;
    padding: 1rem;
    margin: 1rem 0;
    border-radius: 0 6px 6px 0;
    color: #0c4a6e;
  }

  .prediction-note {
    background: #f0fdf4;
    border: 1px solid #bbf7d0;
    padding: 1rem;
    border-radius: 6px;
    margin: 1rem 0;
    color: #166534;
  }

  .visualization-note {
    background: #fffbeb;
    border: 1px solid #fed7aa;
    padding: 1rem;
    border-radius: 6px;
    margin: 1rem 0;
    color: #92400e;
  }

  /* Responsive Design */
  @media (max-width: 768px) {
    .main {
      margin: 10px;
      padding: 20px;
      border-radius: 8px;
    }

    h2 {
      font-size: 1.8rem;
    }

    div.inputFileDiv {
      grid-template-columns: 1fr;
    }

    div.row {
      flex-direction: column;
      align-items: stretch;
    }

    div.graphContainer {
      flex-direction: column;
      align-items: center;
    }

    img.intro_photo {
      max-width: 100%;
    }

    div.intro {
      min-width: auto;
      width: 100%;
    }
  }

  @media (max-width: 480px) {
    .main {
      margin: 5px;
      padding: 15px;
    }

    h2 {
      font-size: 1.5rem;
    }

    button {
      width: 100%;
      margin: 0.25rem 0;
    }
  }
</style>
