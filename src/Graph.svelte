<script>
    import * as d3 from "d3";
    import { tooltip } from './tooltip'

    export let data = [];
    export let width = 600;
    export let height = 448;
    export let margin = { top: 10, right: 10, bottom: 50, left: 50 };

    $: xScale = d3
        .scaleLinear()
        .domain([-5, 6])
        .range([margin.left, width - margin.right]);

    $: yScale = d3
        .scaleLinear()
        .domain([-5, 5])
        .range([height - margin.bottom, margin.top]);

    let xAxis;
    let yAxis;

    $: {
        d3.select(yAxis).call(d3.axisLeft(yScale));
        d3.select(xAxis).call(d3.axisBottom(xScale));
    }
</script>

<svg {width} {height}>
    <image
        href="./graph_bg.png"
        height={height - margin.bottom - margin.top}
        width={width - margin.left - margin.right}
        transform="translate({margin.left}, {margin.top})"
        preserveAspectRatio="none"
    />
    {#each data as data, index}
        <circle 
            cx={xScale(data.x)} 
            cy={yScale(data.y)} 
            r={6} 
            fill="#964B00" 
            title="{data?.name}"
            use:tooltip
        />
    {/each}

    <g transform="translate(0, {height - margin.bottom})" bind:this={xAxis} />
    <g transform="translate({margin.left}, 0)" bind:this={yAxis} />
    <text
        class="label"
        text-anchor="middle"
        x={width / 2}
        y={height - 5}>LD1</text>
    <text
        class="ylabel"
        text-anchor="middle"
        transform="translate(15, {height/2}) rotate(-90)"
        >LD2</text>
</svg>

<style>
    circle {
        z-index: 1;
        opacity: 0.7;
    }

    circle:hover {
        transition: 0.5s;
        opacity: 1;
        z-index: 2;
    }
</style>
