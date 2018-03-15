podTemplate(
    label: 'omisego',
    containers: [
        containerTemplate(
            name: 'jnlp',
            image: 'gcr.io/omise-go/jenkins-slave-elixir:latest',
            args: '${computer.jnlpmac} ${computer.name}',
            alwaysPullImage: true
        ),
    ],
) {
    node('omisego') {
        stage('Checkout') {
            checkout scm
        }

        stage('Build') {
            sh("mix do local.hex --force, local.rebar --force")
            sh("apt-get install -y libgmp3-dev")
            withEnv(["MIX_ENV=test"]) {
                sh("mix do deps.get, deps.compile, compile")
            }
        }

        stage('Build Geth temp') {
          sh("export PATH=/usr/local/go/bin:${PATH}")
          withEnv(["GOLANG_VERSION=\"1.9.2\""]) {
            sh("GOLANG_DOWNLOAD_URL=\"https://golang.org/dl/go${GOLANG_VERSION}.linux-amd64.tar.gz\" && GOLANG_DOWNLOAD_SHA256=\"de874549d9a8d8d8062be05808509c09a88a248e77ec14eb77453530829ac02b\" && curl -fSL -o golang-bin.tar.gz \"${GOLANG_DOWNLOAD_URL}\" && echo \"${GOLANG_DOWNLOAD_SHA256}  golang-bin.tar.gz\" | sha256sum -c - && tar -xzC /usr/local -f golang-bin.tar.gz && rm golang-bin.tar.gz")
          }
          sh("go version")
          withEnv(["GETHPATH=\"/go_ethereum\"", "GETH_VERSION=\"v1.7.3\""]) {
            sh("mkdir -p ${GETHPATH}")
          }
          withEnv(["GETHPATH=\"/go_ethereum\"", "GETH_VERSION=\"v1.7.3\""]) {
            sh("cd ${GETHPATH} && git init && git remote add origin https://github.com/ethereum/go-ethereum && git fetch --depth 1 origin \"${GETH_VERSION}\" && git checkout FETCH_HEAD && make geth")
          }
          withEnv(["GETHPATH=\"/go_ethereum\"", "GETH_VERSION=\"v1.7.3\""]) {
            sh("export PATH=\"${GETHPATH}/build/bin/:${PATH}\"")
          }
          sh("geth version")
        }

        stage('Test') {
            withEnv(["MIX_ENV=test"]) {
                sh("mix coveralls.html --umbrella")
            }
        }

        stage('Lint') {
            withEnv(["MIX_ENV=test"]) {
                sh("mix credo")
            }
        }

        stage('Cleanbuild') {
            withEnv(["MIX_ENV=test"]) {
                sh("mix compile --force --warnings-as-errors")
            }
        }
/*
        stage('Dialyze') {
            sh("mix dialyzer --halt-exit-status")
        }
*/
    }
}
