defmodule Location_supervisor do
  @moduledoc """
  Information of all locations
  """

  @doc """
  Initializes the loop with a map of location bound to the type of location they are

  ## Parameters:
  - locations: [{%Virus_sim.Location, pid()}] A list of tuples containing the location-struct (minus the location_list) and pid of all locations.
  
  """
  
  def init(locations) do
    locations_map = %{
      work: get_locations_of_type(locations, :work, []),
      store: get_locations_of_type(locations, :store, []),
      park: get_locations_of_type(locations, :park, []),
      restaurant: get_locations_of_type(locations, :restaurant, []),
      transport: get_locations_of_type(locations, :transport, []),
      gym: get_locations_of_type(locations, :gym, []),
      cinema: get_locations_of_type(locations, :cinema, []),
    }
    loop(locations_map)
  end
  
  @doc """
  The control loop of a stateful location_supervisor. 
  Holds all current locations.

  ## Parameters:
  - locations: %{type: [{%Virus_sim.Location, pid()}]...} A map lists with locations of the same type at the same key. keys = type of location :work | :store | :park | :restaurant | :transport | :gym | :cinema
  
  ## Messages:
  - {:get_random_location, pid, type}: Sends the %Virus_sim.Location and pid of a random location with a specific type.
  """
  def loop(locations) do
    receive do	
      {:get_random_location, pid, type} ->
	if Map.get(locations, type) == [] do
	  send pid, {:return_random_location, []}
	else
	  location = Enum.random(Map.get(locations, type))
	  send pid, {:return_random_location, location}
	end
	loop(locations)
    end
  end

  @doc """
  Gets a list of locations with a specific type
  
  ## Parameters: 
  - locations: [{%Virus_sim.Location, pid()}] All locations
  - type: atom() The type of the location
  - list: The accumulated list of the locations with a specific type
  """
  def get_locations_of_type([location], type, list) do
    {struct, _pid} = location
    if type == struct.type do
      [location | list]
    else
      list
    end
  end

  def get_locations_of_type([location | tail], type, list) do
    {struct, _pid} = location
    if type == struct.type do
      get_locations_of_type(tail, type, [location | list])
    else
      get_locations_of_type(tail, type, list)
    end
  end
 
end
