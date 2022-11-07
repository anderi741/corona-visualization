import {
	returnData,
	channel,
	stop_channel,
	mainPid,
	personSupervisorPid,
	emptyArray,
	r0Result,
} from "./socket";

let refresh; //Mainloop timer, global variable to be accessible on button presses.

$(document).ready(function () {
	/**
	 * These sets the starting values of the sliders + adds a '%'
	 *  */ 
	$("#asymptomatic_rate_range").val($("#asymptomatic_rate").val() + "%");
	$("#death_rate_range").val($("#death_rate").val() + "%");
	$("#infection_rate_range").val($("#infection_rate").val());
	$("#icb_range").val($("#icb").val());


	/**
	 * Adds an event listener when the sliders is changed that updates the output field in the html change on 
	 */
	
	document.getElementById("asymptomatic_rate").addEventListener("input", function(e) {
		$("#asymptomatic_rate_range").val(e.target.value + "%")
	})

	document.getElementById("death_rate").addEventListener("input", function(e) {
		$("#death_rate_range").val(e.target.value + "%")
	})

	document.getElementById("infection_rate").addEventListener("input", function(e) {
		$("#infection_rate_range").val(e.target.value)
	})

	document.getElementById("icb").addEventListener("input", function(e) {
		$("icb_range").val(e.target.value)
	})
	


	/**
	 * This makes sure that you never can drag the asymptomatic and death rate sliders so they're sum is > 100
	 */
	let maxAsymp = 50;
	let maxDeath = 50;
	$("#death_rate").change(function (e) {
		e.preventDefault();
		if ($(this).val() > maxDeath) {
			$(this).val(maxDeath);
		}
		maxDeath = 100 - $("#asymptomatic_rate").val();
		maxAsymp = 100 - maxDeath + (maxDeath - $(this).val());
		$("#death_rate_range").val($(this).val() + "%");
	});
	$("#asymptomatic_rate").change(function (e) {
		console.log("as");
		e.preventDefault();
		if ($(this).val() > maxAsymp) {
			$(this).val(maxAsymp);
			$("#asymptomatic_rate_range").val(maxAsymp);
		}
		maxAsymp = 100 - $("#death_rate").val();
		maxDeath = 100 - maxAsymp + (maxAsymp - $(this).val());
		$("#asymptomatic_rate_range").val($(this).val() + "%");
	});
});

let createdLocations = [];
let startValues = {};

/**
 * When the start button is clicked
 * We collect the input values and checks that they're valid and then we send them to the channel to start the simulation
 */

$("#start-button").on("click", (e) => {
	e.preventDefault();
	var populationSize = $("#population-size").val();
	var infectionRate = $("#infection_rate").val();
	var deathRate = $("#death_rate").val();
	var asymptomaticRate = $("#asymptomatic_rate").val();
	var incubTimeFrom = $("#incub-time-from").val();
        var incubTimeTo = $("#incub-time-to").val();
        var icb = $("#icb").val();
	
	if (
		!parseInt(populationSize) > 0 ||
		!parseFloat(infectionRate) > 0 ||
		!parseInt(deathRate) > 0 ||
		!parseInt(asymptomaticRate) > 0 ||
		!parseInt(incubTimeFrom) > 0 ||
		!parseInt(incubTimeTo) > 0 
	) {
		alert("Don't leave a field empty");
	} else if (parseInt(incubTimeFrom) > parseInt(incubTimeTo)) {
		alert("The incubation time can't have a lower To value than From value");
	} else if (parseInt(asymptomaticRate) + parseInt(deathRate) > 100) {
		alert("Asymptomatic rate and death rate can't be above 100%");
	} else if (!(parseInt(populationSize) >= 200 && parseInt(populationSize) <= 200000)) {
	        alert("Population size can only be between 200 and 200 000");
	}

	// Starts the simulation by sending a message through a channel to communicate with backend
	else {
		if (infectionRate % 1 === 0) {
			infectionRate = parseInt(infectionRate).toFixed(2);
		}
		startValues = {
			no_people: populationSize,
			infectionRate: infectionRate,
			deathRate: deathRate,
			asymptomaticRate: asymptomaticRate,
			incubTimeFrom: incubTimeFrom,
		        incubTimeTo: incubTimeTo,
		        icb: icb,
		};
		channel.push("sim_start", {
			no_people: populationSize,
			infectionRate: infectionRate,
			deathRate: deathRate,
			asymptomaticRate: asymptomaticRate,
			incubTimeFrom: incubTimeFrom,
		        incubTimeTo: incubTimeTo,
		        icb: icb,
		});
		// A timer that will run until we get our first data from returnData()
		const init = setInterval(function () {
			let done = init_graphs(returnData());
			let test = returnData()
			console.log(test)
			createdLocations = init_locations(returnData());
			console.log(createdLocations);
			if (done) {
				console.log("Initialized graphs");
				clearInterval(init);
			}
		}, 1000);

		// A timer that will run until the number of infected people reaches 0
		refresh = setInterval(function () {
			let done = main_loop(returnData(), createdLocations);
			if (done) {
				console.log("Simulation stopped!");
				clearInterval(refresh);

				stop_channel.push("r0_result", { personSupervisorPid }, 10000);

				stop_channel.push("sim_stop", { mainPid }, 10000);

				$("#results").show();
				$("#results-facts-and-values").hide()
				fixResults(startValues);
				$(".loader").show(800);
				$("#r0-result").text("");

				$("#countermeasures").hide();
				$("html, body").animate(
					{
						scrollTop: $("#results").offset().top,
					},
					2000
				);
				$(".stop-button").addClass("done-button");
				$(".stop-button").html("Simulation done. Press to exit");
			}
		}, 1000);

		/**
		 * Animation for the transition of the containers
		 */
		$("#start-button").hide(1000);
		$("#start-form-container").hide(1000, function () {
			$([document.documentElement, document.body]).animate(
				{
					scrollTop: $("#total_charts").offset().top,
				},
				2000
			);
		});
		$(".stop-button").show(1000);
		counterMeasureRestyle($("#lockdown"), true);
		counterMeasureRestyle($("#socialdistancing"), true);
		counterMeasureRestyle($("#none"), false);
		$("#countermeasures").show(1000);
		$("#total_charts").show(1000);
		console.log(startValues)
	}
});

/**
 * When we press the stop button in the simulation we change which DOM-elements we render + stop the simulation by pushing to the channel
 */
$(".stop-button").on("click", function (e) {
	shapes = []
	clearInterval(refresh);
	e.preventDefault();
	$("#countermeasures").hide();
	$("#total_charts").hide();
	$("#results").hide();

	$("#start-form-container").show(800);
	$("#start-button").show(800);
	$(".stop-button").hide(800, function () {
		if ($(".stop-button").hasClass("done-button")) {
			$(".stop-button").removeClass("done-button");
			$(".stop-button").html("Stop simulation");
		} else {
			stop_channel.push("sim_stop", { mainPid }, 10000);
		}
	});

	emptyArray();
});

/**
 * When we want to save the result we need to hide som buttons that we couldn't render
 */
$("#save-result-button").on("click", function() {
	$(".done-button").hide(0)
	let temp = $("#footer-text").html()
	$("#footer-text").html("Made by CORONA - Albin, Alexander, Andreas, Anton, Johan, Robin, Sebastian | (1DT096) 2020")
	window.print()
	$("#footer-text").html(temp)
	$(".done-button").show(0)
})

// ***************************
// COUNTERMEASURE BUTTON LOGIC
// ***************************

/**
 * Restyles the buttons and send a counter measure to backend through channel
*/


$("#none").on("click", function (e) {
	counterMeasureRestyle($("#lockdown"), true);
	counterMeasureRestyle($("#socialdistancing"), true);
	counterMeasureRestyle($("#none"), false);
        stop_channel.push("no_measures", { personSupervisorPid }, 10000);
	addVertLine("rgba(51, 204, 51,0.7)")
	

});


$("#socialdistancing").on("click", function (e) {
	counterMeasureRestyle($("#lockdown"), true);
	counterMeasureRestyle($("#none"), true);
	counterMeasureRestyle($("#socialdistancing"), false);
        stop_channel.push("social_distancing", { personSupervisorPid }, 10000);	
	addVertLine("rgba(255, 153, 0, 0.7)")
	
});

$("#lockdown").on("click", function (e) {
	counterMeasureRestyle($("#none"), true);
	counterMeasureRestyle($("#socialdistancing"), true);
	counterMeasureRestyle($("#lockdown"), false);
        stop_channel.push("lockdown", { personSupervisorPid }, 10000);
	addVertLine("rgba(255,0,0,0.7)")
	
});

let shapes = [] // Contains the vertical lines we have created for the graph

/**
 * When a countermeasure button is pressed this function creates a vertical line at that tick in the line graph
 * @param {String} color color for that particular vertical line
 */

function addVertLine(color) {
	const retDbButton = returnData();
	let tick = (retDbButton[retDbButton.length - 1].counter)/24;

	let newShape = {
		type: 'line',
		x0: tick,
		x1: tick,
		y0: 0,
		y1: startValues.no_people,
		line: {
			color: color,
			width: 2
		},
	}
	shapes.push(newShape)

	let layoutUpdate = {
		title: title,
		width: 800,
		xaxis: {
			title: "# Days",
		},
		yaxis: {
			title: "# People",
		},
		shapes: shapes
	};

    Plotly.react("line_chart_total", layoutUpdate)
}

/**
 * This function is called when the simulation is done
 * It adds a <span></span> to the correct DOM-element with the result that we got from the simulation + some text
 * to display it prettier
 * @param {Object} startValues the values we started the sim with
 */
function fixResults(startValues) {
	let popSize = startValues.no_people;
	let data = getTotalStats(returnData()); // Hämtar väl data från senaste ticket? Alltså det sista
	console.log(data)
	$("#result-pop-size").html("<span class=result-list-text>Your simulation with " + popSize + " people resulted in:</span>");
	$("#result-deaths").html("<span class=result-list-text>" + data[2] + " died from the disesase </span>")
	$("#result-recovered").html("<span class=result-list-text>" + data[3] + " recovered from the disease </span>")	
	$("#result-not-infected").html("<span class=result-list-text>" + (popSize - data[2] - data[3]) + " never got the disease </span>")	
}

/**
 * Resets the button to the original style if reset = true else it will be styled as a clicked button.
 * @param {String} div The div of the button
 * @param {boolean} reset If the button should be clicked or reset back to the original style
 */
function counterMeasureRestyle(div, reset) {
	if (reset) {
		div.css("background-color", "#1E9574");
		div.css("box-shadow", "none");
	} else {
		div.css("background-color", "#0d7965");
		div.css(
			"box-shadow",
			"inset 7px 0 9px -7px rgba(0,0,0,0.4), inset -7px 0 9px -7px rgba(0,0,0,0.4)"
		);
	}
}

/**
 * Initilizes the current graphs with the first values from the broadcasted returnData()
 *
 * @param {{counter: integer(), data: Array()}} db
 *
 * @return {bool} true if the graphs has been initialized, false if we haven't received any data
 * from returnData()
 */
function init_graphs(db) {
	let totalStats = getTotalStats(db);

	if (totalStats) {
		initPieChart(
			[totalStats[0], totalStats[1], totalStats[2], totalStats[3]],
			["Healthy", "Infected", "Deaths", "Recovered"],
			["rgb(0, 204, 0)", "rgb(255, 0, 0)", "rgb(0, 0, 0)", "rgba(255, 153, 0, 0.7)"],
			"Total",
			"pie_chart_total"
		);
		initLineChart(
			db[db.length - 1].counter,
			[totalStats[0], totalStats[1], totalStats[2], totalStats[3]],
			["Healthy", "Infected", "Deaths", "Recovered"],
			["rgb(0, 204, 0)", "rgb(255, 0, 0)", "rgb(0, 0, 0)", "rgba(255, 153, 0, 0.7)"],
			"Total",
			"line_chart_total"
		);
		return true;
	}
	return false;
}

/**
 * Updates the graphs with new values received from returnData()
 *
 * @param {{counter: integer(), data: Array()}} db
 *
 * @return {false} returns false when the amount of infected reaches 0
 */
function main_loop(db, createdLocations) {
	let totalStats = getTotalStats(db);

	if (db && totalStats) {
		updatePieChart(
			[totalStats[0], totalStats[1], totalStats[2], totalStats[3]],
			["Healthy", "Infected", "Deaths", "Recovered"],
			["rgb(0, 204, 0)", "rgb(255, 0, 0)", "rgb(0, 0, 0)", "rgba(255, 153, 0, 0.7)"],
			"Total",
			"pie_chart_total"
		);

		updateLineChart(
			db[db.length - 1].counter,
			[totalStats[0], totalStats[1], totalStats[2], totalStats[3]],
			"line_chart_total"
		);

		//updateBarChart(newStats);
		fixLocationBarChart(db, createdLocations, true);

		if (totalStats[1] == 0) {
			return true;
		}
	}
}

/**
 * Gets the latest data from returnData()
 *
 * @param {{counter: integer(), data: Array()}} db
 *
 * @return {[not_infected, infected, deaths, recovered]} A list of the amount of people with
 * different statuses.
 * {not_infected} The amount of not_infected people.
 * {infected} The amount of infected people.
 * {deaths} The amount of dead people.
 * {recovered} The amount of recovered people.
 */
function getTotalStats(db) {
	if (db.length > 0) {
		let latest_tick_data = db[db.length - 1].data;

		let not_infected = latest_tick_data
			.map(({ not_infected }) => not_infected)
			.reduce(function (a, b) {
				return a + b;
			}, 0);

		let infected = latest_tick_data
			.map(({ infected }) => infected)
			.reduce(function (a, b) {
				return a + b;
			}, 0);

		let deaths = latest_tick_data
			.map(({ dead }) => dead)
			.reduce(function (a, b) {
				return a + b;
			}, 0);

		let recovered = latest_tick_data
			.map(({ recovered }) => recovered)
			.reduce(function (a, b) {
				return a + b;
			}, 0);

		return [not_infected, infected, deaths, recovered];
	}
}

/**
 * Initialize and plots the pie chart
 *
 * @param {[integer(), integer(), integer(), integer()]} values The values to be inserted
 * @param {[String, String, String, String]} labels The labels of the values
 * @param {["rgb(r, g, b)", "rgb(r, g, b)", "rgb(r, g, b)", "rgb(r, g, b)"]} colors The colors of
 * the values
 * @param {String} title The title of the pie chart
 * @param {String} div The div of the pie chart
 *
 */
function initPieChart(values, labels, colors, title, div) {
	let pie_data = [
		{
			values: values,
			labels: labels,
			marker: {
				colors: colors,
			},
			title: {
				text: name,
				font: {
					family: "Courier New, monospace",
					size: 24,
				},
			},
			type: "pie",
		},
	];

	let pie_layout = {
		title: title,
		height: 400,
		width: 400,
	};

	let config = { responsive: true };

	Plotly.newPlot(div, pie_data, pie_layout, config);
}

/**
 * Goes through the data and creates a list with the types of locations that we have
 * Calls fixLocationBarChart that creates the chart with these locations
 * @param {Array} db the db with all the ticks
 */
function init_locations(db) {
	console.log(db)
	let tick = db[0].data;
	let createdLocation = [];
	for (let i = 0; i < tick.length; i++) {
		// Inits all locations
		let created = false;
		let name;
		if (tick[i].type == null) {
			name = tick[i].name;
			if (name != "Graveyard" && name != "Hospital") {
				createdLocation.push(name);
			}
		} else {
			for (let j = 0; j < createdLocation.length; j++) {
				if (createdLocation[j] == tick[i].type) {
					//Already created
					created = true;
					break;
				}
			}
			if (created == false) {
				name = tick[i].type;
				createdLocation.push(name);
			}
		}
	}
	fixLocationBarChart(db, createdLocation, false);
	return createdLocation;
}
/**
 * Creates the bar chart for the location types
 * @param {Array} db the data that we have
 * @param {Array} createdLocations list of the types of locations that we have in the data
 * @param {Bool} update A bool that's True if it's an update of the chart or False if we should make a new plot
 */
function fixLocationBarChart(db, createdLocations, update) {
	let stats = getLocationStats(db, createdLocations);
	let barData = [];
	let statuses = ["Healthy", "Infected", "Recovered"];
	for (let i = 0; i < statuses.length; i++) {
		let x = [];
	        let y = [];
	        let color;
		for (let j = 0; j < stats.length; j++) {
			x.push(stats[j].name);
			switch (statuses[i]) {
				case "Healthy":
			                y.push(stats[j].not_infected);
			                color = {color: 'rgb(0, 204, 0)'}
					break;
				case "Infected":
			                y.push(stats[j].infected);
			                color = {color: 'rgb(255, 0, 0)'}
					break;
			        case "Recovered":
			                y.push(stats[j].recovered);
			                color = {color: 'rgba(255, 153, 0, 0.7)'}
					break;
				default:
					break;
			}
		}
		let statusData = {
			x: x,
			y: y,
		        name: statuses[i],
		        marker: color,
		        type: "bar"
		};
		barData.push(statusData);
	}
	let maxPeople = startValues.no_people;
	console.log(maxPeople);
	let layout = {
		barmode: "stack",
		title: "Data for location types",
		yaxis: { autorange: false, range: [0, maxPeople] },
		width: 400,
		height: 400,
	};
	if (update === true) {
		Plotly.react("location-stat-chart", barData, layout);
	} else {
		Plotly.newPlot("location-stat-chart", barData, layout);
	}
}

/**
 * Returns a list with the stats for each location-type at the latest tick
 * @param {Array} db the database with all the ticks
 * @param {Array} createdLocations list with the location types this simulation contains
 */
function getLocationStats(db, createdLocations) {
	let latest_tick = db[db.length - 1].data;
	let retData = [];
	for (let i = 0; i < createdLocations.length; i++) {
		let data;
		let infected = 0;
		let not_infected = 0;
		let recovered = 0;
		let dead = 0;
		let name;
		for (let j = 0; j < latest_tick.length; j++) {
			let tickData = latest_tick[j]; // Så man slipper skriva [j] 100 gånger
			if (tickData.type == null && tickData.name == createdLocations[i]) {
				//Hospital, home, graveyard (finns bara en)
				name = tickData.name;
				infected = tickData.infected;
				not_infected = tickData.not_infected;
				recovered = tickData.recovered;
				dead = tickData.dead;
				break;
			}
			if (tickData.type == createdLocations[i]) {
				name = tickData.type;
				infected = infected + tickData.infected;
				not_infected = not_infected + tickData.not_infected;
				recovered = recovered + tickData.recovered;
				dead = dead + tickData.dead;
			}
		}
		data = {
			name: name,
			infected: infected,
			not_infected: not_infected,
			recovered: recovered,
			dead: dead,
		};
		retData.push(data);
	}
	return retData;
}

/**
 * Updates and plots the pie chart
 *
 * @param {[integer(), integer(), integer(), integer()]} values The new values to be inserted
 * @param {[String, String, String, String]} labels The labels of the values
 * @param {["rgb(r, g, b)", "rgb(r, g, b)", "rgb(r, g, b)", "rgb(r, g, b)"]} colors The colors of
 * the values
 * @param {String} title The title of the pie chart
 * @param {String} div The div of the pie chart
 *
 * @OBS Creates a whole new plot with the new values, could be more efficient to do it in another
 * way.
 */
function updatePieChart(values, labels, colors, title, div) {
	let pie_data = [
		{
			values: values,
			labels: labels,
			marker: {
				colors: colors,
			},
			title: {
				text: name,
				font: {
					family: "Courier New, monospace",
					size: 24,
				},
			},
			type: "pie",
		},
	];

	let pie_layout = {
		title: title,
		height: 400,
		width: 400,
	};

	let config = { responsive: true };

	Plotly.newPlot(div, pie_data, pie_layout, config);
}

/**
 * Initialize and plots the line chart
 *
 * @param {counter} counter The current tick
 * @param {[integer(), integer(), integer(), integer()]} values The values to be inserted
 * @param {[String, String, String, String]} labels The labels of the values
 * @param {["rgb(r, g, b)", "rgb(r, g, b)", "rgb(r, g, b)", "rgb(r, g, b)"]} colors The colors of
 * the values
 * @param {String} title The title of the line chart
 * @param {String} div The div of the line chart
 *
 */
function initLineChart(counter, values, labels, colors, title, div) {
	let trace_not_infected = {
		x: [counter / 24],
		y: [values[0]],
		name: labels[0],
		mode: "lines",
		line: {
			color: colors[0],
			width: 2,
		},
	};

	let trace_infected = {
		x: [counter / 24],
		y: [values[1]],
		name: labels[1],
		mode: "lines",
		line: {
			color: colors[1],
			width: 2,
		},
	};

	let trace_deaths = {
		x: [counter / 24],
		y: [values[2]],
		name: labels[2],
		mode: "lines",
		line: {
			color: colors[2],
			width: 2,
		},
	};

	let trace_recovered = {
		x: [counter / 24],
		y: [values[3]],
		name: labels[3],
		mode: "lines",
		line: {
			color: colors[3],
			width: 2,
		},
	};

	let data = [
		trace_not_infected,
		trace_infected,
		trace_deaths,
		trace_recovered,
	];
	let layout = {
		title: title,
		width: 800,
		xaxis: {
			title: "# Days",
		},
		yaxis: {
			title: "# People",
		},
		shapes: shapes
	};

	let config = { responsive: true };

	Plotly.newPlot(div, data, layout, config);
}

/**
 * Updates and extends the traces of the line chart
 *
 * @param {counter} counter The current tick
 * @param {[integer(), integer(), integer(), integer()]} new_data The new values to extend the
 * traces
 * @param {String} div The div of the line chart
 *
 */
function updateLineChart(counter, new_data, div) {
	let data = {
		y: [[new_data[0]], [new_data[1]], [new_data[2]], [new_data[3]]],
		x: [[counter / 24], [counter / 24], [counter / 24], [counter / 24]],
	};
	Plotly.extendTraces(div, data, [0, 1, 2, 3]);
}
