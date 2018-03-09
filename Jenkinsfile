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
            withEnv(["MIX_ENV=test"]) {
                sh("mix do deps.get, deps.compile")
            }
        }

        stage('Test') {
            withEnv(["MIX_ENV=test"]) {
                sh("mix test")
            /*
                sh("mix do credo, coveralls.html --umbrella --no-start --include integration")
                sh("mix dialyzer --halt-exit-status")
            */
            }
        }
    }
}
