# how to renew "Apple Push Services Certificate"

About two times a year, we get an email from Apple
reminding to renew the "Apple Push Services Certificate"
(used for the heartbeat server to help the app waking up)

These are the steps needed for renewal:


## 1. create signing-request 

- on mac-desktop, launch "Keychain Access" app, (maybe you need to have an xcode dev certificate)
- in main menu: Keychain Access > Certificate Assistant > Request a Certificate from a Certificate Authority.
- email: `delta-ios@merlinux.eu`, name: `delta-apns`
- save locally as `certificates/YEAR-push-renew-NUMBER/CertificateSigningRequest.certSigningRequest` (do not add to git)


## 2. create `.cer` file

- open <https://developer.apple.com/account/resources/certificates/add>, hit "Create"
- select "Apple Push Notification service SSL (Sandbox & Production)"
- App ID: `8Y...A8.chat.delta`
- upload `CertificateSigningRequest.certSigningRequest` from above
- download locally to `certificates/YEAR-push-renew-NUMBER/aps.cer` (do not add to git)


## 3. convert to `.p12` [^1]

- create `certificates/YEAR-push-renew-NUMBER/password.txt` containing nothing but a suffciently secure password
- double click downloaded `aps.cer` file, this opens again the app "KeyChain Access"
  (if that is not working, open "KeyChain Access", select "login" keychain and then "File / Import Item" and select `aps.cer`)
- select "Certificates" and then expand the new item (the new one is usally the one expiration date most far in the future)
- select **both**, "certificate" and "private key" (but not "public key")
- right click, "Export 2 items"
- save locally as `certificates/YEAR-push-renew-NUMBER/Certificates.p12`,
  you'll be prompted for a password, enter the one from `password.txt`


## 4. renew on server

In case you cannot do the server-side update yourself,
ping server admins to renew the certificate
and send them `Certificates.p12` and `password.txt` through a secure channel.

The server code itself is hosted on <https://github.com/deltachat/notifiers>.


[^1]: source: <https://stackoverflow.com/questions/9418661/how-to-create-p12-certificate-for-ios-distribution/28962937#28962937>
