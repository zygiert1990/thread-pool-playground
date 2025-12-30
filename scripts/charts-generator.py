#!/usr/bin/env python3
import pandas as pd
from pathlib import Path
import re
import sys

def main():
    # Get root directory from command line argument or use current directory
    if len(sys.argv) > 1:
        root_dir = Path(sys.argv[1])
    else:
        root_dir = Path('.')

    if not root_dir.exists():
        print(f"Error: Directory '{root_dir}' does not exist")
        sys.exit(1)

    print(f"Scanning directory: {root_dir.absolute()}")

    # Find all app-metrics.csv files and extract labels
    data = {}
    max_duration = 0

    for csv_path in root_dir.glob('*/app-metrics.csv'):
        # Extract parent directory name (e.g., 'CTP_20251229-140352')
        dir_name = csv_path.parent.name

        # Remove timestamp suffix (pattern: _YYYYMMDD-HHMMSS)
        label = re.sub(r'_\d{8}-\d{6}$', '', dir_name)

        # Load CSV
        try:
            df = pd.read_csv(csv_path)

            # Normalize timestamps: start from 0 and increment by 2
            df['relative_time'] = [i * 2 for i in range(len(df))]

            # Track the longest duration
            duration = int(df['relative_time'].max())
            if duration > max_duration:
                max_duration = duration

            print(f"  Loaded: {csv_path.parent.name} → Label: '{label}' ({len(df)} rows, {duration}s duration)")

        except Exception as e:
            print(f"  Error loading {csv_path}: {e}")
            continue

        # Handle duplicate labels if same prefix appears multiple times
        original_label = label
        counter = 1
        while label in data:
            label = f"{original_label}_{counter}"
            counter += 1

        data[label] = df

    if not data:
        print("\nNo app-metrics.csv files found!")
        print("Expected structure: root_dir/PREFIX_TIMESTAMP/app-metrics.csv")
        sys.exit(1)

    # Sort by label for consistent ordering
    data = dict(sorted(data.items()))

    print(f"\nFound {len(data)} datasets: {list(data.keys())}")
    print(f"Max duration across all datasets: {max_duration} seconds")

    # Load 95th percentile results
    percentile_file = root_dir / 'results-95-percentile.csv'
    percentile_labels = []
    percentile_values = []

    if percentile_file.exists():
        try:
            percentile_df = pd.read_csv(percentile_file)
            percentile_labels = percentile_df.columns.tolist()
            percentile_values = percentile_df.iloc[0].tolist()
            print(f"Loaded 95th percentile data: {len(percentile_labels)} configurations")
        except Exception as e:
            print(f"Warning: Could not load {percentile_file}: {e}")
    else:
        print(f"Warning: {percentile_file} not found, skipping 95th percentile chart")

    # Calculate 8 GB in KB: 8 * 1024 * 1024 = 8388608 KB
    max_rss_kb = 8 * 1024 * 1024

    # Build HTML content
    html_content = """
<!DOCTYPE html>
<html>
<head>
    <title>JVM Metrics Comparison</title>
    <script src="https://cdn.plot.ly/plotly-2.27.0.min.js"></script>
    <style>
        body {
            margin: 0;
            padding: 20px;
            font-family: Arial, sans-serif;
            background-color: #f5f5f5;
        }
        h1 {
            text-align: center;
            color: #333;
            margin-bottom: 30px;
        }
        .chart-container {
            background: white;
            margin-bottom: 30px;
            padding: 15px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
    </style>
</head>
<body>
    <h1>JVM Metrics Comparison</h1>
"""

    # Add 95th percentile chart if data exists
    if percentile_labels and percentile_values:
        html_content += """    <div class="chart-container" id="percentile-chart"></div>
"""

    html_content += """    <div class="chart-container" id="cpu-chart"></div>
    <div class="chart-container" id="rss-chart"></div>
    <div class="chart-container" id="threads-chart"></div>

    <script>
"""

    # Add 95th percentile chart
    if percentile_labels and percentile_values:
        html_content += f"""
        // 95th Percentile Chart Data
        var percentileTrace = {{
            x: {percentile_labels},
            y: {percentile_values},
            type: 'bar',
            marker: {{
                color: 'rgb(55, 128, 191)',
                line: {{
                    color: 'rgb(8, 48, 107)',
                    width: 1.5
                }}
            }}
        }};

        var percentileLayout = {{
            title: '95th Percentile Results',
            xaxis: {{
                title: 'Configuration',
                tickangle: -45
            }},
            yaxis: {{
                title: 'Value (ms)'
            }},
            height: 500,
            margin: {{
                b: 120
            }}
        }};

        Plotly.newPlot('percentile-chart', [percentileTrace], percentileLayout, {{responsive: true}});

"""

    html_content += """        // CPU Chart Data
        var cpuTraces = [
"""

    # Add CPU traces
    for name, df in data.items():
        x_data = df['relative_time'].tolist()
        y_data = df['cpu_percent_per_core'].tolist()
        html_content += f"""
            {{
                x: {x_data},
                y: {y_data},
                name: '{name}',
                type: 'scatter',
                mode: 'lines',
                line: {{width: 2}}
            }},
"""

    html_content += f"""
        ];

        var cpuLayout = {{
            title: 'CPU Percent per Core',
            xaxis: {{
                title: 'Time (seconds)',
                range: [0, {max_duration}]
            }},
            yaxis: {{
                title: 'CPU %',
                range: [0, 400]
            }},
            hovermode: 'x unified',
            height: 500
        }};

        Plotly.newPlot('cpu-chart', cpuTraces, cpuLayout, {{responsive: true}});

        // RSS Chart Data
        var rssTraces = [
"""

    # Add RSS traces
    for name, df in data.items():
        x_data = df['relative_time'].tolist()
        y_data = df['rss_kb'].tolist()
        html_content += f"""
            {{
                x: {x_data},
                y: {y_data},
                name: '{name}',
                type: 'scatter',
                mode: 'lines',
                line: {{width: 2}}
            }},
"""

    html_content += f"""
        ];

        var rssLayout = {{
            title: 'Memory usage in KB',
            xaxis: {{
                title: 'Time (seconds)',
                range: [0, {max_duration}]
            }},
            yaxis: {{
                title: 'Memory (KB)',
                range: [0, {max_rss_kb}]
            }},
            hovermode: 'x unified',
            height: 500
        }};

        Plotly.newPlot('rss-chart', rssTraces, rssLayout, {{responsive: true}});

        // Threads Chart Data
        var threadsTraces = [
"""

    # Add Threads traces
    for name, df in data.items():
        x_data = df['relative_time'].tolist()
        y_data = df['threads'].tolist()
        html_content += f"""
            {{
                x: {x_data},
                y: {y_data},
                name: '{name}',
                type: 'scatter',
                mode: 'lines',
                line: {{width: 2}}
            }},
"""

    html_content += f"""
        ];

        var threadsLayout = {{
            title: 'Threads',
            xaxis: {{
                title: 'Time (seconds)',
                range: [0, {max_duration}]
            }},
            yaxis: {{
                title: 'Thread Count'
            }},
            hovermode: 'x unified',
            height: 500
        }};

        Plotly.newPlot('threads-chart', threadsTraces, threadsLayout, {{responsive: true}});
    </script>
</body>
</html>
"""

    # Save to single HTML file
    output_file = root_dir / 'jvm_metrics_comparison.html'
    with open(output_file, 'w') as f:
        f.write(html_content)

    print(f"\n✅ Chart saved to: {output_file.absolute()}")

    # Open in browser
    import webbrowser
    webbrowser.open(f'file://{output_file.absolute()}')

if __name__ == "__main__":
    main()