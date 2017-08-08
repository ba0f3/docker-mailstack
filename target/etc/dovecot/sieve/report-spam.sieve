require ["vnd.dovecot.pipe", "copy", "imapsieve", "environment", "imap4flags"];

if environment :is "imap.cause" "COPY" {
  pipe :copy "dovecot-lda" [ "-d", "spam@example.com", "-m", "report_spam" ];
                }

# Catch replied or forwarded spam
elsif anyof (allof (hasflag "\\Answered",
                    environment :contains "imap.changedflags" "\\Answered"),
             allof (hasflag "$Forwarded",
                    environment :contains "imap.changedflags" "$Forwarded")) {
 pipe :copy "dovecot-lda" [ "-d", "spam@example.com", "-m", "report_spam_reply" ];
}
