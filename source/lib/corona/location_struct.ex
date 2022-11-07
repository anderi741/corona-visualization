defmodule Virus_sim.Location do
  @moduledoc """
  Template struct for locations
  """
  @doc """
  - name: String, The name of the location.
  - location_list: [pid()] A list of people in this location
  - counter: the pid of the associated location counter
  - type: :work | :store | :park | :restaurant | :transport | :gym | :cinema nil, the type of location it is, should never be nil
  - time_range: {integer(), integer()} the {low, high} range of how long a person is usually at the location, in hours
  - infection_rate: float(), 0.1-1 how infectious the location is, 1 max. 0.1 is min
  ## Ratio
  - :work|:store|:park |:rest |:trans|:gym |:cinem| 
  - 50   | 10   | 1    | 10   | 20   | 4   | 5    | = how many of each there are | spawn_generic_locations
  - 100  | 200  | 1000 | 100  | 50   | 100 | 200  | = average max people per location | spawn_generic_locations
  - 5000 | 2000 | 1000 | 1000 | 1000 | 400 | 1000 | = total amount of people if 100 locations | none
  - 32   | 20   | 4    | 12   | 16   | 8   | 8    | = chance to move there | movement_logic
  - 0.8  | 0.3  | 0.1  | 0.4  | 0.6  | 1   | 0.5  | = infection_rate | spawn_generic_locations
  """
  defstruct name: "",
    location_list: [],
    counter: nil,
    type: nil,
    time_range: nil,
    infection_rate: nil
end
