# What this is

This takes the data from https://github.com/nytimes/covid-19-data/ for
a single county and converts it.

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

