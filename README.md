# What this is

This makes a lot of visualizations of the data from
https://github.com/nytimes/covid-19-data including:

- A full website with web pages showing doubling time for each and every
  county and state in the US
- A map of the US showing per-state COVID-19 growth
- CSV and ASCII tables showing growth for a given state or county

# Demo

Go to https://samboy.github.io/covid-19-html/ to see what this
program can do.  Go to https://www.samiam.org/COVID-19/ to see doubling
time graphs for each and every county and state in the United States.

# Making a webpage with doubling time graphs for each state

Needed 

- Git
- Lua
- Gnuplot
- Bash (Windows users: Install Cygwin)

In this directory:

```bash
git clone https://github.com/nytimes/covid-19-data/
cp covid-19-data/us-counties.csv data.csv
lua examine-growth.lua gnuplot
cd GNUplot/
for FILE in *gnuplot ; do
  gnuplot "$FILE"
  echo "$FILE"
done
cp USA.html index.html
```

Once the New York Times repo is cloned:

```bash
cd covid-19-data/
git pull origin master
cd ..
cp covid-19-data/us-counties.csv data.csv
lua examine-growth.lua gnuplot
cd GNUplot/
for FILE in *gnuplot ; do
  gnuplot "$FILE"
  echo "$FILE"
done
cp USA.html index.html
```

The Lua script makes the .html files and the files needed to make
the PNG graphs.  Gnuplot makes the physical PNG files.

# Making a SVG map

To make a SVG map of the data, make sure one has Git and the 
programming language Lua (5.1 or higher) installed.  Then, run
the following commands:

```sh
git clone https://github.com/nytimes/covid-19-data/
cp covid-19-data/us-counties.csv data.csv
lua examine-growth.lua svg > map.svg
```

There are other options to the `examine-growth.lua` script, such as:

* `lua examine-growth.lua csv Texas > texas.csv`
* `lua examine-growth.lua cases Florida`
* `lua examine-growth.lua svg casesPer100k > map.svg`

One can get full command line options with 
`lua examine-growth.lua --help`

# Using the JSON file as an API

The JSON file is in the form

state → county → date → (cases, deaths)

For example, here is some data for San Diego:

```json
{
	"California": {
		"San Diego" : {
			"2020-03-22" : {
				"cases": 205, "deaths": 0
			},
			"2020-03-23" : {
				"cases": 230, "deaths": 0
			},
			"2020-03-24" : {
				"cases": 242, "deaths": 1
			},
			"2020-03-25" : {
				"cases": 297, "deaths": 2
			}
		}
	}
}
```

Here is an example of using this JSON to get the current number of cases
in San Diego, California:

```html
<html><head>
<script src="libs/jquery-3.4.1.min.js"></script>
<script>
$.ajax({
        url: "https://samboy.github.io/covid-19-html/covid-19-byCounty.json",
        dataType: "json",
        success: function(result) {
                dates = result.California["San Diego"]
                cases = 0
                for(key in dates) {
                        if(dates.hasOwnProperty(key)) {
                                value = dates[key]
                                if(value.cases > cases) {
                                        cases = value.cases;
                                }
                        }
                }
                $("#dynamic").html("<i>Current information:</i> " +
                        "San Diego has " + cases +
                        " known COVID-19 cases.");
        }
});
</script>
</head>
<body>
This is a demo of using the JSON data as an API.

<div id=dynamic></div>
<noscript>Javascript will allow current San Diego figures for COVID-19 
to be loaded</noscript>
</body></html>
```

# Attribution

The data used here is provided by 
[The New York Times](https://github.com/nytimes/covid-19-data).
