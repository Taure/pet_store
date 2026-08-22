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
                {"/pets/:id", fun pets_controller:show/1, #{methods => [get]}},
                {"/docs/[...]", "openapi"}
            ]
        },
        #{
            prefix => "/api",
            security => fun pet_store_auth:require_authenticated/1,
            plugins => [
                {pre_request, nova_request_plugin, #{decode_json_body => true}}
            ],
            routes => [
                {"/pets", fun pets_controller:create/1, #{methods => [post]}},
                {"/pets/:id", fun pets_controller:update/1, #{methods => [put]}},
                {"/pets/:id", fun pets_controller:delete/1, #{methods => [delete]}}
            ]
        },
        #{
            prefix => "/api",
            security => false,
            plugins => [
                {pre_request, nova_request_plugin, #{decode_json_body => true}}
            ],
            routes => [
                {"/register", fun pet_store_registration_controller:create/1, #{methods => [post]}},
                {"/login", fun pet_store_session_controller:create/1, #{methods => [post]}}
            ]
        },
        #{
            prefix => "/api",
            security => fun pet_store_auth:require_authenticated/1,
            plugins => [
                {pre_request, nova_request_plugin, #{decode_json_body => true}}
            ],
            routes => [
                {"/logout", fun pet_store_session_controller:delete/1, #{methods => [delete]}},
                {"/me", fun pet_store_user_controller:show/1, #{methods => [get]}},
                {"/me/password", fun pet_store_user_controller:update_password/1, #{
                    methods => [put]
                }},
                {"/me/email", fun pet_store_user_controller:update_email/1, #{methods => [put]}}
            ]
        }
    ].
