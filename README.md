# What this is

This takes the data from https://github.com/nytimes/covid-19-data/ for
a single county and converts it.  We can make tabular data or a SVG map
of the Unites States visualizing data.

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

# Trying to predict growth

I am working on trying to make an accurate model for predicting COVID-19
growth based on the per-county figures we have with COVID-19 (courtesy
The New York Times).  To say the data is noisy would be an understatement.

What I have found, so far, is that if we look at current daily growth
(averaged over seven days) and use exponentiation to predict future
growth based on the previous week’s figures, the numbers are too high
(usually by a factor of two, but the error amount is all over the place).

Point being, we’re seeing a more complicated growth model than simple
exponential growth; the actual growth is lower.

*This is a work in progress* and I’m nowhere near being able to make
a simple easy to read graph showing a reasonable projection of COVID-19
growth in the United States.

# Output formats

Possible output formats are:

* An HTML table
* A CSV file
* A JSON file

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
