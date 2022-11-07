defmodule CoronaWeb.DataChannel do
  use Phoenix.Channel
  def join("data", _payload, socket) do
    {:ok, socket}
  end

  def handle_in("main_pid", msg, socket) do
    push socket, "main_pid", msg
    {:no_reply, socket}
  end

  def handle_in("person_supervisor_pid", msg, socket) do
    push socket, "person_supervisor_pid", msg
    {:no_reply, socket}
  end

  def handle_in("sim_data", msg, socket) do
    push socket, "sim_data", msg
    {:noreply, socket}
  end

  def handle_in("sim_start", %{"no_people" => no_people, "infectionRate" => infectionRate, "deathRate" => deathRate, "asymptomaticRate" => asymptomaticRate, "incubTimeFrom" => incubTimeFrom, "incubTimeTo" => incubTimeTo, "icb" => icb}, socket) do
    popSize = String.to_integer(no_people)
    infectionPercent = String.to_float(infectionRate)
    deathRatePercent = String.to_integer(deathRate)
    asymptomaticRatePercent = String.to_integer(asymptomaticRate)
    incubTimeFromInt = String.to_integer(incubTimeFrom)
    incubTimeToInt = String.to_integer(incubTimeTo)
    icb = String.to_integer(icb)
    Virus_sim.init(popSize, infectionPercent, {incubTimeFromInt, incubTimeToInt}, {deathRatePercent, asymptomaticRatePercent}, icb)
    
    {:noreply, socket}
  end

end
