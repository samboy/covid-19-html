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

# Making a website of doubling time graphs

It is possible to use these scripts to make an entire website with
doubling time graphs for each state and county in the US.

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
gnuplot maps.gnuplot
```

Once the New York Times repo is cloned:

```bash
cd covid-19-data/
git pull origin master
cd ..
cp covid-19-data/us-counties.csv data.csv
lua examine-growth.lua gnuplot
cd GNUplot/
gnuplot maps.gnuplot
```

It’s also possible to make the .svg top-level map a .png file (for
maximum browser compatibility) if `ImageMagick` is installed:

```bash
convert -depth 8 GNUplot/hotSpots.svg GNUplot/hotSpots.png
cat GNUplot/index.html | sed 's/hotSpots.svg/hotSpots.png/g' > foo
mv foo GNUplot/index.html
```

The Lua script makes the .html files and the files needed to make
the PNG graphs.  Gnuplot makes the actual PNG files.

# The web site

The `maps.gnuplot` and the `.csv` files are not needed on the actual
web site.  Only the `.html`, `.png`, and one `.svg` file are needed.
The files make a static web site which can be hosted by almost any
web server.  The web site is about 170 megabytes in size (all of those
`.png` graphs for each and every county in the United States add up).

To view the created web site, one can open up `GNUplot/index.html` using
any modern browser from the mid-2010s or later; the website will work
with Internet Explorer if the `.svg` file is converted in to a `.png`
file.

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
