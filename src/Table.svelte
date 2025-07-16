<script>
  export let tableData;
  export let style;
</script>

<table class={style}>
  <thead>
    <tr>
      {#each Object.keys(tableData[0]) as columnHeading}
        <th>{columnHeading}</th>
      {/each}
    </tr><tr />
  </thead>
  <tbody>
    {#each Object.values(tableData) as row}
      <tr>
        {#each Object.values(row) as cell}
          <td>{cell}</td>
        {/each}
      </tr>
    {/each}
  </tbody>
</table>

<style>
  /* Default professional table styling */
  table {
    width: 100%;
    border-collapse: collapse;
    margin: 20px 0;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    border-radius: 8px;
    overflow: hidden;
    background-color: #ffffff;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen,
      Ubuntu, Cantarell, sans-serif;
  }

  table th {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: #ffffff;
    font-weight: 600;
    padding: 16px 12px;
    text-align: left;
    font-size: 14px;
    letter-spacing: 0.5px;
    text-transform: uppercase;
    border: none;
    position: relative;
  }

  table th:not(:last-child)::after {
    content: "";
    position: absolute;
    right: 0;
    top: 20%;
    height: 60%;
    width: 1px;
    background: rgba(255, 255, 255, 0.2);
  }

  table td {
    padding: 14px 12px;
    border: none;
    border-bottom: 1px solid #e5e7eb;
    font-size: 14px;
    color: #374151;
    transition: background-color 0.2s ease;
  }

  table tbody tr {
    transition: all 0.2s ease;
  }

  table tbody tr:nth-child(even) {
    background-color: #f9fafb;
  }

  table tbody tr:hover {
    background-color: #f3f4f6;
    transform: translateY(-1px);
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
  }

  table tbody tr:last-child td {
    border-bottom: none;
  }

  /* Enhanced Red Table Theme */
  table.redTable {
    border-radius: 10px;
    overflow: hidden;
    box-shadow: 0 6px 20px rgba(164, 8, 8, 0.15);
    background-color: #ffffff;
  }

  table.redTable th {
    background: linear-gradient(135deg, #dc2626 0%, #991b1b 100%);
    color: #ffffff;
    font-size: 15px;
    font-weight: 700;
    padding: 18px 16px;
    text-align: center;
    letter-spacing: 0.8px;
    text-transform: uppercase;
    border: none;
    position: relative;
  }

  table.redTable th:not(:last-child)::after {
    content: "";
    position: absolute;
    right: 0;
    top: 25%;
    height: 50%;
    width: 1px;
    background: rgba(255, 255, 255, 0.3);
  }

  table.redTable td {
    padding: 16px;
    border: none;
    border-bottom: 1px solid #fee2e2;
    font-size: 14px;
    text-align: center;
    color: #450a0a;
    font-weight: 500;
  }

  table.redTable tbody tr:nth-child(even) {
    background-color: #fef2f2;
  }

  table.redTable tbody tr:hover {
    background-color: #fecaca;
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(164, 8, 8, 0.1);
  }

  /* Enhanced Blue Table Theme */
  table.blueTable {
    border-radius: 10px;
    overflow: hidden;
    box-shadow: 0 6px 20px rgba(28, 110, 164, 0.15);
    background-color: #ffffff;
  }

  table.blueTable th {
    background: linear-gradient(135deg, #2563eb 0%, #1e40af 100%);
    color: #ffffff;
    font-size: 15px;
    font-weight: 700;
    padding: 18px 16px;
    text-align: left;
    letter-spacing: 0.5px;
    border: none;
    position: relative;
  }

  table.blueTable th:not(:last-child)::after {
    content: "";
    position: absolute;
    right: 0;
    top: 25%;
    height: 50%;
    width: 1px;
    background: rgba(255, 255, 255, 0.3);
  }

  table.blueTable td {
    padding: 16px;
    border: none;
    border-bottom: 1px solid #e0f2fe;
    font-size: 14px;
    color: #0c4a6e;
    font-weight: 500;
  }

  table.blueTable tbody tr:nth-child(even) {
    background-color: #f0f9ff;
  }

  table.blueTable tbody tr:hover {
    background-color: #bae6fd;
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(28, 110, 164, 0.1);
  }

  /* Modern minimal table theme */
  table.minimal {
    border: none;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
    border-radius: 6px;
  }

  table.minimal th {
    background: #f8fafc;
    color: #64748b;
    font-weight: 600;
    font-size: 13px;
    padding: 12px 16px;
    border-bottom: 2px solid #e2e8f0;
  }

  table.minimal td {
    padding: 12px 16px;
    border-bottom: 1px solid #f1f5f9;
  }

  table.minimal tbody tr:hover {
    background-color: #f8fafc;
  }

  /* Dark theme table */
  table.dark {
    background-color: #1f2937;
    color: #f9fafb;
  }

  table.dark th {
    background: linear-gradient(135deg, #374151 0%, #1f2937 100%);
    color: #f9fafb;
  }

  table.dark td {
    border-bottom-color: #374151;
    color: #d1d5db;
  }

  table.dark tbody tr:nth-child(even) {
    background-color: #111827;
  }

  table.dark tbody tr:hover {
    background-color: #374151;
  }

  /* Responsive design */
  @media (max-width: 768px) {
    table {
      font-size: 12px;
    }

    table th,
    table td {
      padding: 8px 6px;
    }

    table.redTable th,
    table.blueTable th {
      font-size: 13px;
      padding: 12px 8px;
    }
  }
</style>
