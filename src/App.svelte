<script>
  import Table from "./Table.svelte";
  import * as d3 from "d3";
  import { onMount } from "svelte";

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
            getResultResponseJson["message"]["status"]["S"] == "finished" &&
            getResultResponseJson["message"]["graph_status"]["S"] == "finished"
          ) {
            console.log(getResultResponseJson["message"]);
            let resultText = getResultResponseJson["message"]["result"]["S"];
            let graphResult =
              getResultResponseJson["message"]["graph_result"]["S"];
            let resultTableData = resultText.split(",").map((text) => {
              let temp = text.split(":");
              return { "Sequence meta": temp[0], Prediction: temp[1] };
            });
            return [
              resultTableData,
              getResultResponseJson["message"]["graph_result"]["S"],
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

  // d3
  let width = 4650;
  let height = 400;

  let margin = { top: 10, right: 10, bottom: 75, left: 20 };

  let data = [];
  onMount(async function () {
    data = []
  });

  $: xScale = d3
    .scalePoint()
    .domain([-5, 6])
    .range([margin.left, width - margin.right]);

  $: yScale = d3
    .scaleLinear()
    .domain([-5, 5])
    .range([height - margin.bottom, margin.top]);

  $: colorScale = d3
    .scaleOrdinal(d3.schemeTableau10)
    .domain(data.map((d) => d.region));

  let xAxis;
  let yAxis;

  $: {
    d3.select(yAxis).call(d3.axisLeft(yScale));

    d3.select(xAxis)
      .call(d3.axisBottom(xScale))
      .selectAll(".tick > text")
      .attr("y", 0)
      .attr("dy", "0.35em")
      .attr("dx", "-1em")
      .attr("text-anchor", "end")
      .attr("transform", "rotate(-90)");
  }
</script>

<div class="main">
  <h1><center>Prediction for sustained transmission by Yong Tao</center></h1>
  <h2>Sequence Type</h2>
  <div class="row">
    <label class="runtypebutton">
      <input type="radio" bind:group={runtype} name="runtype" value="CDS" />
      Protein coding region
    </label>
    <label>
      <input type="radio" bind:group={runtype} name="runtype" value="WGS" />
      Whole genome segments
    </label>
  </div>
  <h2>Fasta files upload</h2>
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
  <button on:click={handleSubmit}>Submit</button>
  {#await promise}
    <p>File is uploading and calculating results...</p>
  {:then res}
    {#if res}
      <p>Success, here is the result:</p>
      <Table tableData={res[0]} style="blueTable" />
      <svg {width} {height}>
        {#each data as d, i}
          <circle
            cx={xScale(d.country)}
            cy={yScale(d.health)}
            r={7}
            height={yScale(0) - yScale(d.health)}
            fill={colorScale(d.region)}
          />
        {/each}

        <g
          transform="translate(0, {height - margin.bottom})"
          bind:this={xAxis}
        />

        <g transform="translate({margin.left}, 0)" bind:this={yAxis} />
      </svg>
    {/if}
  {:catch error}
    <p>Error occured: {error.message}</p>
  {/await}
</div>

<style>
  .main {
    width: 100%;
    height: 100%;
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

  svg {
    border: 2px dashed goldenrod;
  }

  circle {
    stroke: white;
    z-index: 1;
  }
</style>
