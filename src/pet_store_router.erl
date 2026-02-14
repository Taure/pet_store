-module(pet_store_router).
-behaviour(nova_router).

-export([routes/1]).

routes(_Environment) ->
    [
        #{
            prefix => "/api",
            security => false,
            plugins => [
                {pre_request, nova_request_plugin, #{decode_json_body => true}}
            ],
            routes => [
                {"/pets", fun pets_controller:index/1, #{methods => [get]}},
                {"/pets", fun pets_controller:create/1, #{methods => [post]}},
                {"/pets/:id", fun pets_controller:show/1, #{methods => [get]}},
                {"/pets/:id", fun pets_controller:update/1, #{methods => [put]}},
                {"/pets/:id", fun pets_controller:delete/1, #{methods => [delete]}}
            ]
        }
    ].
