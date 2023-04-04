<script>
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
        const urlRes = await fetch("https://7dw7gs4iynbh5sygciwg5f4wky0vepdw.lambda-url.us-east-1.on.aws/?" + "runtype=" + runtype);

        if (urlRes.ok) {
            const postDetail = await urlRes.json();
            const urls = postDetail["url_responses"];
            console.log(postDetail)
            jobid = postDetail["job_id"]
            let successUpload = 0;
            for (const seqType in urls) {
                let mfile;
                switch (seqType) {
                    case 'HA':
                        mfile = HAfile;
                        break;
                    case 'NA':
                        mfile = NAfile;
                        break;
                    case 'NP':
                        mfile = NPfile;
                        break;
                    case 'PA':
                        mfile = PAfile;
                        break;
                    case 'PB1':
                        mfile = PB1file;
                        break;
                    case 'PB2':
                        mfile = PB2file;
                        break;
                    case 'M':
                    case 'M1':
                        mfile = Mfile;
                        break;
                    case 'NS':
                    case 'NS1':
                        mfile = NSfile;
                        break;
                }

                const formData = new FormData();
                Object.keys(urls[seqType].fields).forEach((key) => {
                    formData.append(key, urls[seqType].fields[key])
                })
                formData.append('file', mfile[0])
                console.log(formData)
                const uploadRes = await fetch(urls[seqType].url, {
                    method: 'POST',
                    mode: 'cors',
                    body: formData
                })
                if (uploadRes.ok) {
                    successUpload++;
                } else {
                    return new Error("Error during s3 upload");
                }
            }

            console.log(successUpload)
            if (successUpload == 8) {
                const uploadRes = await fetch("https://duz5hhucocqrcvc4ub6ukcu26i0zrczv.lambda-url.us-east-1.on.aws/?jobid=" + jobid + "&runtype=" + runtype)
                if (uploadRes.ok) {
                    // TODO: how to get job result?
                } else {
                    return new Error("Error during s3 upload");
                }
            } else {
                console.log(successUpload)
            }
            
            // if (uploadRes.ok) {
            //     // Use presigned url to fetch object from s3 bucket 'usher-output'
            //     let trial = 0
            //     while(true) {
            //         const gzkey = postDetail.id.substring(0, postDetail.id.length - 5) + 'tar.gz' 
            //         await new Promise(r => setTimeout(r, 20000))
            //         const getResult = await fetch("https://usher-output.s3.amazonaws.com/" + gzkey)
            //         if (getResult.ok) {
            //             console.log("result ready!")
            //             downloadURL = "https://usher-output.s3.amazonaws.com/" + gzkey
            //             return "Success! please click the button below to download the result file."
            //         } else {
            //             console.log("result not yet!")
            //             if (trial > 60) {
            //                 throw new Error("Result cannot be found on the server.")
            //             } else {
            //                 trial++;
            //             }
            //         }
            //     }
            // } else {
            //     return new Error("Error during s3 upload");
            // }
        } else {
            return new Error("Error during /upload-url");
        }
    }
    let promise;
    function handleSubmit() {
        // if (HAfile?.[0] && NAfile?.[0] && NPfile?.[0] && PAfile?.[0] && PB1file?.[0] && PB2file?.[0] && Mfile?.[0] && NSfile?.[0]) {
            promise = submit();
        // }
    }

</script>

<div class="main">
	<h1><center>Prediction for sustained transmission by Yong Tao</center></h1>
    <h2>Sequence Type</h2>
    <div class="row">
        <label class="runtypebutton">
            <input type=radio bind:group={runtype} name="runtype" value="CDS">
            Protein coding region
        </label>
        <label>
            <input type=radio bind:group={runtype} name="runtype" value="WGS">
            Whole genome segments
        </label>
    </div>
    <h2>Fasta files upload</h2>
    <label>
        HA: 
        <input type="file" accept=".fasta" bind:files={HAfile}/>
    </label>
    <label>
        NA: 
        <input type="file" accept=".fasta" bind:files={NAfile}/>
    </label>
    <label>
        NP: 
        <input type="file" accept=".fasta" bind:files={NPfile}/>
    </label>
    <label>
        PA: 
        <input type="file" accept=".fasta" bind:files={PAfile}/>
    </label>
    <label>
        PB1: 
        <input type="file" accept=".fasta" bind:files={PB1file}/>
    </label>
    <label>
        PB2: 
        <input type="file" accept=".fasta" bind:files={PB2file}/>
    </label>
    <label>
        {runtype == "CDS" ? "M1" : "M"}: 
        <input type="file" accept=".fasta" bind:files={Mfile}/>
    </label>
    <label>
        {runtype == "CDS" ? "NS1" : "NS"}: 
        <input type="file" accept=".fasta" bind:files={NSfile}/>
    </label>
    <button on:click={handleSubmit}>Submit</button>
    {#await promise}
        <p>File is uploading and calculating results...</p>
    {:then res} 
        {#if res}
        <p>{res}</p>
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
</style>