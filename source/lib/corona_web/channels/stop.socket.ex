defmodule CoronaWeb.StopChannel do
  use Phoenix.Channel
  def join("stop", _payload, socket) do
    {:ok, socket}
  end

  def handle_in("sim_stop", %{"mainPid" => mainPid}, socket) do
    to_atom = String.to_atom(mainPid)
    Virus_sim.stop_sim(to_atom)
    
    {:noreply, socket}
  end

  def handle_in("no_measures", %{"personSupervisorPid" => personSupervisorPid}, socket) do
    to_atom = String.to_atom(personSupervisorPid)
    send Process.whereis(to_atom), {:send_to_all, :no_measures}
    {:noreply, socket}
  end

  def handle_in("social_distancing", %{"personSupervisorPid" => personSupervisorPid}, socket) do
    to_atom = String.to_atom(personSupervisorPid)
    send Process.whereis(to_atom), {:send_to_all, :social_distancing}
    {:noreply, socket}
  end

  def handle_in("lockdown", %{"personSupervisorPid" => personSupervisorPid}, socket) do
    to_atom = String.to_atom(personSupervisorPid)
    send Process.whereis(to_atom), {:send_to_all, :lockdown}
    {:noreply, socket}
  end

  def handle_in("r0_result", %{"personSupervisorPid" => personSupervisorPid}, socket) do
    to_atom = String.to_atom(personSupervisorPid)
    send Process.whereis(to_atom), {:get_r0, self()}
    receive do
      {:return_r0, r0} ->
	push socket, "r0_result", %{"r0" => r0}
    end
    {:noreply, socket}
  end
  
end
