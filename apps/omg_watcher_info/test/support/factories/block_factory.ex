# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.WatcherInfo.Factory.BlockFactory do
  defmacro __using__(_opts) do
    quote do
      def block_factory do
        %OMG.WatcherInfo.DB.Block{
          blknum: 1,
          hash: <<1::256>>,
          eth_height: 1,
          timestamp: 1 #DateTime.from_iso8601("2019-12-12T01:01:01Z") |> DateTime.to_unix(),
        }
      end
    end
  end
end


# returns %{blknum: 1, hash: <<1::256>>, eth_height: 1, timestamp: ....}
#build(:block)

# returns %{blknum: 2, hash: <<1::256>>, eth_height: 1, timestamp: ....}
#build(:user, blknum: 2)


# attrs = %{body: "A comment!"} # attrs is optional. Also accepts a keyword list.
# build(:comment, attrs)
# build_pair(:comment, attrs)
# build_list(3, :comment, attrs)

# # `insert*` returns an inserted comment. Only works with ExMachina.Ecto
# # Associated records defined on the factory are inserted as well.
# insert(:comment, attrs)
# insert_pair(:comment, attrs)
# insert_list(3, :comment, attrs)

# # `params_for` returns a plain map without any Ecto specific attributes.
# # This is only available when using [`ExMachina.Ecto`](ExMachina.Ecto.html).
# params_for(:comment, attrs)

# # `params_with_assocs` is the same as `params_for` but inserts all belongs_to
# # associations and sets the foreign keys.
# # This is only available when using [`ExMachina.Ecto`](ExMachina.Ecto.html).
# params_with_assocs(:comment, attrs)

# # Use `string_params_for` to generate maps with string keys. This can be useful
# # for Phoenix controller tests.
# string_params_for(:comment, attrs)
# string_params_with_assocs(:comment, attrs)



# ecto associations
#
# Using insert/2 in factory definitions may lead to performance issues and bugs, as records will be saved unnecessarily.
#
# def article_factory do
#   %Article{
#     title: "Use ExMachina!",
#     # associations are inserted when you call `insert`
#     comments: [build(:comment)],
#     author: build(:user),
#   }
# end



# flexible factories with pipes

# def make_admin(user) do
#   %{user | admin: true}
# end

# def with_article(user) do
#   insert(:article, user: user)
#   user
# end

# build(:user) |> make_admin |> insert |> with_article
