package examples

import (
	gsl "greymatter.io/gsl/v1"

	"examples.module/greymatter:globals"
)


Shark: gsl.#Service & {
	// A context provides global information from globals.cue
	// to your service definitions.
	context: Shark.#NewContext & globals

	// name must follow the pattern namespace/name
	name:          "shark"
	display_name:  "Examples Shark"
	version:       "v1.0.0"
	description:   "EDIT ME"
	api_endpoint:              "https://\(context.globals.edge_host)/services/\(context.globals.namespace)/\(name)/"
	api_spec_endpoint:         "https://\(context.globals.edge_host)/services/\(context.globals.namespace)/\(name)/"
	
	business_impact:           "low"
	owner: "Examples"
	capability: ""
	health_options: {
		spire: gsl.#SpireUpstream & {
			#context: context.SpireContext
			#subjects: ["greymatter-datastore"]
		}
	}
	// Shark -> ingress to your container
	ingress: {
		(name): {
			gsl.#HTTPListener
			gsl.#SpireListener & {
				#context: context.SpireContext
				#subjects: ["examples-edge"]
			}
			
			//  NOTE: this must be filled out by a user. Impersonation allows other services to act on the behalf of identities
			//  inside the system. Please uncomment if you wish to enable impersonation. If the servers list if left empty,
			//  all traffic will be blocked.
			filters: [
				gsl.#ImpersonationFilter & {
						#options: {
							servers: "CN=alec.jolmes,OU=Engineering,O=Decipher Technology Studios,L=Alexandria,ST=Virginia,C=US|x500UniqueIdentifier=e68ef81ca228f4dc66dd5ad696386d96,O=SPIRE,C=US"
							caseSensitive: false
						}
				},
				gsl.#RBACFilter & {
					#options: {
						"rules": {
							action: "ALLOW"
							policies: {
								"0-admin": {
									permissions: [
										{
											any: true
										},
									]
									principals: [
										{
											"header": {
												"name":        "user_dn"
												"exact_match": "x500UniqueIdentifier=f07a39d626691f0d9cb311867d93abe1,O=SPIRE,C=US"
											}
										},
										{
											"header": {
												"name":        "user_dn"
												"exact_match": "x500UniqueIdentifier=41e6ca07852a9a84e80cde0563ab0c02,O=SPIRE,C=US"
											}
										},
									]
								}
								"1-public": {
									"permissions": [
										{
											"header": {
												"name": ":path"
												"safe_regex_match": {
													"google_re2": {}
													"regex": "^/*.*(/users/.*/accesses|/userattributes|/snippets).*$"
												}
												"invert_match": true
											}
										},
									]
									"principals": [
										{
											"any": true
										},
									]
								}
							}
						}
					}
				},
				gsl.#FaultInjectionFilter & {
					#options: {
						abort: {
							// header_abort: {} // Headers can also specify the percentage of requests to fail, capped by the below value with the x-envoy-fault-abort-request-percentage header
							percentage: {
								numerator: 10
								denominator: "HUNDRED"
							}
							http_status: 404
						}
					}
				}
			]
			routes: {
				"/": {
					
					upstreams: {
						"local": {
							gsl.#Upstream
							
							instances: [
								{
									host: "127.0.0.1"
									port: 9090
								},
							]
						}
					}
				}
			}
		}
	}


	
	// Edge config for the Shark service.
	// These configs are REQUIRED for your service to be accessible
	// outside your cluster/mesh.
	edge: {
		edge_name: "edge"
		routes: "/services/\(context.globals.namespace)/\(name)": {
			prefix_rewrite: "/"
			upstreams: (name): {
				gsl.#Upstream
				namespace: context.globals.namespace
				gsl.#SpireUpstream & {
					#context: {
						globals.globals
						service_name: "edge"
					}
					#subjects: ["examples-shark"]
				}
			}
		}
	}
	
}

exports: "shark": Shark
