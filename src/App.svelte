<script>
  import Table from "./Table.svelte";
  import Graph from "./Graph.svelte";

  // settings
  const fetchInterval = 2 * 1000; // get result fetch interval in milliseconds
  const maxFetch = 100; // max get result fetch until error
  const maxErrorFetch = 5; // max fetch for getting error
  const tableColNameSeq = "Sequence Name";
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
  let runtype = "CDS"; // "CDS" or "WGS"
  let promise = null;

  const checkResponse = (response, responseJson, expectedKeys) => {
    if (!response.ok) {
      console.error(`JSON return code not ok: ${response.status}`);
      return new Error("Error: Cannot connect to the server.");
    }
    if ("error" in responseJson) {
      console.error("error key appears in response JSON");
      console.error(json.error);
      throw new Error(`Error: Server error.`);
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
        `https://wxgjeui7qfjttffrvrfcuuftsa0aflnb.lambda-url.us-east-1.on.aws/?jobid=${jobid}&runtype=${runtype}`,
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
          "graph_result" in getResultResponseJson
        ) {
          const resultText = getResultResponseJson["result"]["S"];
          let resultTextLines = resultText.split("\n");
          let transformedResultText = [];
          for (let x = 0; x < resultTextLines.length; x += 2) {
            transformedResultText = [
              ...transformedResultText,
              {
                [tableColNameSeq]: resultTextLines[x],
                [tableColNamePrediction]: resultTextLines[x + 1],
              },
            ];
          }
          console.log(transformedResultText);
          let graphResultJson = JSON.parse(
            getResultResponseJson["graph_result"]["S"]
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
</script>

<svelte:head>
  <title>Risk assessment of sustained mammalian transmission of influenza A viruses</title>
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
  <div class="graphContainer">
    <img class="intro_photo" src="./intro.png" alt="Graph introduction" />
    <div class="intro">
      <p>
        Upload eight protein coding regions (HA, NA, NP, PA, PB1, PB2, M1 and
        NS1) or eight nucleotide segments (HA, NA, NP, PA, PB1, PB2, MP and NS)
        to assess the risk of sustained transmission in mammals for avian or recently zoonotic influenza A viruses. Details in
        <a href="https://github.com/id-bioinfo/IAV_GCContent" target="_blank"
          >https://github.com/id-bioinfo/IAV_GCContent</a
        >.
      </p>
    </div>
  </div>

  <h3>Choose sequence type:</h3>
  <div class="row">
    <label class="runtypebutton">
      <input type="radio" bind:group={runtype} name="runtype" value="CDS" />
      Protein coding region (recommended)
    </label>
    <label>
      <input type="radio" bind:group={runtype} name="runtype" value="WGS" />
      Nucleotide segment
    </label>
  </div>
  <h3>Select your FASTA sequences:</h3>
  {#each Object.entries(inputFiles) as [inputType, _]}
    <label>
      {inputType === "M"
        ? runtype === "CDS"
          ? "M"
          : "MP"
        : inputType}{#if (inputType === "M" || inputType === "NS") && runtype === "CDS"}1{/if}:
      <input type="file" accept=".fasta" bind:files={inputFiles[inputType]} />
    </label>
  {/each}
  <p>
    <left>
      * Sequence names of the eight protein coding regions or nucleotide
      segments should be the same for each influenza A virus in the input files.
    </left>
  </p>
  {#if promise === null}
    <div class="row">
      <label class="runtypebutton">
        <button on:click={handleSubmit}>Run</button>
      </label>
      <label class="runtypebutton">
        <button on:click={handleRunDemo}>Run demo (Mink H5N1 IAVs)</button>
      </label>
    </div>
  {/if}
  {#await promise}
    <p>Loading...</p>
  {:then res}
    {#if res}
      <h3>SVM Prediction</h3>
      <Table tableData={res[0]} style="blueTable" />
      <p>
        <b>1</b> is sustained transmission potential in mammalian hosts;
        <b>-1</b> is predicted to sporadic infection in mammals. The prediction is
        based on a combination of GC content and CG dinucleotide frequencies of eight
        CDS or segments using developed SVM model.
      </p>
      <h3>Visualization by 2D projection</h3>
      <div class="graphContainer">
        <Graph data={res[1]} />
        <img class="legend" src="./legends.jpeg" alt="Graph legends" />
      </div>
      <p>
        Positions of the tested IAVs (brown points) are shown on the
        distributions of avian and sporadic mammalian IAVs (gray zones), and
        persistent mammalian lineages (red zones), estimated by linear
        discriminant analysis. Hover your mouse on the points to see their
        sequence names. The earliest sequences in persistent mammalian lineages
        are also highlighted.
      </p>
      <!-- <button on:click|once={handleDeleteResult}>Delete result</button> -->
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
    align-items: left;
    justify-content: left;
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
    width: 100dwv;
    flex: 1;
    flex-direction: row;
    flex-wrap: wrap;
    justify-content: left;
    align-items: left;
  }

  img.legend {
    aspect-ratio: 926/631;
    max-height: 447px;
  }

  img.intro_photo {
    float: left;
    width: 450px;
    height: 288px;
    padding-left: 1px;
    padding-right: 5px;
  }
  div.intro {
    float: right;
    width: 400px;
    padding-top: 80px;
  }
</style>
