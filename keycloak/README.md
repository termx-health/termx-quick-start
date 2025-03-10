The instructions here will help you set up the [KeyCloak OpenID server](https://www.keycloak.org/) as an SSO server for authenticating and authorizing users in TermX.

# Install KeyCloak

- We recommend following the KeyCloak [installation and configuration guide](https://www.keycloak.org/server/containers).
- The instructions below describe the quickest way to set up KeyCloak, which may not be suitable for production.
- Navigate to the TermX directory, open `docker-compose.yml` and add the content of [keycloak-docker-compose.yml](keycloak-docker-compose.yml) file manually or using command below:

```bash
cat keycloak/keycloak-docker-compose.yml >> docker-compose.yml
```

- Rebuild Docker containers:

```bash
docker-compose up -d
```

# Configure TermX realm

- Open [`http://localhost:8080`](http://localhost:8080) in your web browser and log in with the username and password specified in the `KEYCLOAK_ADMIN` and `KEYCLOAK_ADMIN_PASSWORD` parameters.
- Import realm using [termx-realm.json](termx-realm.json) file. Please follow the KeyCloak [manual](https://www.keycloak.org/getting-started/getting-started-docker). As result 2 clients will be created: `termx-client` for web app and `termx-service` for server (API calls).
- Add a new user in the TermX realm (for example, “test”), set the credentials, and join group `termx-admin`.
- Add your site as web origin and redirect url. Go to Clients and select `termx-client`.
  - Find 'Valid redirect URIs' and add path of your site (for example `https://termx.mysite.com/*`). Remove unused urls and save configuration.
  - Find 'Web origins' and add path of your site (for example `https://termx.mysite.com`). Remove unused urls and save configuration.
- (optional) Update the client secret for `termx-service`. Go to Clients, select `termx-service`, navigate to credentials, generate new `Client Secret` and save it in `server.env` or `server-keycloak.env` file as a value of the parameter `KEYCLOAK_CLIENT_SECRET`. 

# Reconfigure TermX installation

- Go to `docker-compose.yml` and enable KeyCloak authentication
  - uncomment lines with `server-keycloak.env` and `web-keycloak.env`.
  - comment out line with `web-loginless.env`.
  - the result should look like

```yml
  termx-server:
    ...
    env_file:
      - server.env
      - keycloak/server-keycloak.env

  termx-web:
    ...
    env_file:
      - web.env 
#      - web-loginless.env
      - keycloak/web-keycloak.env
```  

- Navigate to the TermX directory and rebuild Docker containers:

```bash
docker-compose up -d
```

- Open [`http://localhost:4200`](http://localhost:4200) in your web browser.

# Identity providers

To add other identity providers, such as Google, GitHub, and Microsoft authentication, follow
KeyCloak [server administration guide](https://www.keycloak.org/docs/latest/server_admin).

# Default permissions for automatically created user
- Open TermX realm
- Goto “Realm Settings” -> “User registration” tab
- Assign “termx-client: editor” role (or any other suitable role). This role(s) will be added to user automatically after user registration (first login).

# Default timeout
The default timeout of the token in Keycloak is 5 min. You may want to reconfigure this value.
- Open TermX realm and goto “Realm Settings”
- Open “Tokens” tab and change "Access Token Lifespan" to a longer period.
- Open “Sessions” tab and change "SSO Session Idle" to at least twice as long as "Access Token Lifespan".

# Troubleshooting

- Validate the status of TermX server

```bash
docker logs termx-server
```

- Read TermX [tutorial](https://tutorial.termx.org/en/authentication)
- Some computers do not accept container name or `localhost`. Open `http://localhost:8080/realms/termx/protocol/openid-connect/certs` to validate it. If url not resolvable, then replace `localhost` with the IP address of the local machine, such as `127.0.0.1` or `172.17.0.1`, in `server-keycloak.env`.
