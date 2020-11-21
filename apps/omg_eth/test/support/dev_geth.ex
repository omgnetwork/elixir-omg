# Copyright 2019-2020 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.Eth.DevGeth do
  @moduledoc """
    Interaction with docker's geth instance
  """
  use GenServer
  @docker_engine_api "v1.39"

  def start() do
    start(8545)
  end

  def start(port) do
    {:ok, _} = Application.ensure_all_started(:briefly)
    {:ok, _} = Application.ensure_all_started(:httpoison)
    {:ok, pid} = GenServer.start(__MODULE__, [])
    {:ok, container_id} = GenServer.call(pid, {:start, port}, 60_000)
    wait(port)
    {:ok, {pid, container_id}}
  end

  def init(_) do
    {:ok, %{}}
  end

  def handle_call({:start, port}, _, _state) do
    geth_image = pull_geth_image()
    datadir = create_temp_geth_dir()
    container_id = create_geth_container(port, datadir, geth_image)
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    Process.register(self(), String.to_atom(container_id))
    start_container(container_id, port)
    {:reply, {:ok, container_id}, container_id}
  end

  def terminate(_, container_id) when is_binary(container_id) do
    stop_container_url = "http+unix://%2Fvar%2Frun%2Fdocker.sock/#{@docker_engine_api}/containers/#{container_id}/stop"

    stop_response =
      HTTPoison.post!(stop_container_url, "", [{"content-type", "application/json"}],
        timeout: 60_000,
        recv_timeout: 60_000
      )

    204 = stop_response.status_code

    delete_container_url =
      "http+unix://%2Fvar%2Frun%2Fdocker.sock/#{@docker_engine_api}/containers/#{container_id}?v=true&force=true"

    delete_response =
      HTTPoison.delete!(delete_container_url, [{"content-type", "application/json"}],
        timeout: 60_000,
        recv_timeout: 60_000
      )

    204 = delete_response.status_code
    _ = Briefly.cleanup()
  end

  defp wait(port) do
    case Ethereumex.HttpClient.web3_client_version(url: "http://127.0.0.1:#{port}") do
      {:error, :closed} ->
        Process.sleep(500)
        wait(port)

      _ ->
        :ok
    end
  end

  defp start_container(container_id, port) do
    url = "http+unix://%2Fvar%2Frun%2Fdocker.sock/#{@docker_engine_api}/containers/#{container_id}/start"
    response = HTTPoison.post!(url, "", [{"content-type", "application/json"}], timeout: 60_000, recv_timeout: 60_000)

    case response.status_code do
      204 -> :ok
      500 -> raise ArgumentError, message: "Something is running on Geth port #{port}."
    end
  end

  defp create_geth_container(port, datadir, geth_image) do
    body = Jason.encode!(geth(port, datadir, geth_image))
    url = "http+unix://%2Fvar%2Frun%2Fdocker.sock/#{@docker_engine_api}/containers/create"
    response = HTTPoison.post!(url, body, [{"content-type", "application/json"}], timeout: 60_000, recv_timeout: 60_000)
    IO.inspect(response)
    201 = response.status_code
    %{"Id" => id} = Jason.decode!(response.body)
    id
  end

  defp pull_geth_image() do
    path = Path.join([Mix.Project.build_path(), "../../", "docker-compose.yml"])
    {:ok, docker_compose} = YamlElixir.read_from_file(path)
    geth_image = docker_compose["services"]["geth"]["image"]
    url = "http+unix://%2Fvar%2Frun%2Fdocker.sock/#{@docker_engine_api}/images/create?fromImage=#{geth_image}"
    response = HTTPoison.post!(url, "", [])
    200 = response.status_code
    geth_image
  end

  defp create_temp_geth_dir() do
    {:ok, datadir} = Briefly.create(directory: true)
    snapshot_dir = Path.expand(Path.join([Mix.Project.build_path(), "../../", "data/geth/"]))
    {"", 0} = System.cmd("cp", ["-rf", snapshot_dir, datadir])
    datadir
  end

  defp geth(port, datadir, geth_image) do
    root_path = Path.join([Mix.Project.build_path(), "../../"])

    %{
      "Image" => geth_image,
      "Entrypoint" => [
        "/bin/sh",
        "-c",
        ". data/command"
      ],
      "Env" => [
        "RPC_PORT=#{port}"
      ],
      # -p
      "PortBindings" => %{"#{port}/tcp" => [%{"HostIP" => "0.0.0.0", "HostPort" => "#{port}"}]},
      "ExposedPorts" => %{"#{port}/tcp" => %{}},
      "HostConfig" => %{
        "PortBindings" => %{
          "#{port}/tcp" => [
            %{
              "HostIp" => "",
              "HostPort" => "#{port}"
            }
          ]
        },
        "Binds" => [
          "#{root_path}/docker/geth/command:/data/command:rw",
          "#{datadir}:/data:rw",
          "#{root_path}/docker/geth/geth-blank-password:/data/geth-blank-password:rw"
        ]
      }
    }
  end
end
