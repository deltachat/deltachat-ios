#ifndef __DC_CMDLINE_H__
#define __DC_CMDLINE_H__
#ifdef __cplusplus
extern "C" {
#endif


/* Execute a simple command.
- This function is not neeed for the normal program flow but only for debugging purposes
  to give users some special power to the database and to the connection.
- For security reasons, the first command must be `auth <password>`; once authorized, this is
  is valid for _all_ exising and future mailbox objects.  You can skip the authorisation process
  by calling dc_cmdline_skip_auth()
- The returned result may contain multiple lines  separated by `\n` and must be
  free()'d if no longer needed.
- some commands may use dc_log_info() for additional output.
- The command `help` gives an overview */
char*           dc_cmdline           (dc_context_t*, const char* cmd);


/* If the command line authorisation (see dc_cmdline()) is not desired, eg. for a command line client,
you can skip this using dc_cmdline_skip_auth().*/
void            dc_cmdline_skip_auth ();


#ifdef __cplusplus
} // /extern "C"
#endif
#endif // __DC_CMDLINE_H__
