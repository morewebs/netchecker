# Local network test fixtures

The localhost certificate and private key are public, disposable test fixtures.
They are used only by loopback TLS servers in automated tests, never by the app.
The certificate includes localhost, 127.0.0.1 and ::1 and expires in 2036.
