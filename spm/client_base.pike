/* Copyright (C) 2000-2004  Thomas Bopp, Thorsten Hampel, Ludger Merkens
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
 * 
 * $Id: client_base.pike,v 1.1 2008/03/31 13:39:57 exodusd Exp $
 */

constant cvs_version="$Id: client_base.pike,v 1.1 2008/03/31 13:39:57 exodusd Exp $";

inherit "kernel/socket";
inherit "net/coal/binary";

#include <coal.h>
#include <macros.h>
#include <client.h>

private static mapping        mObjects; // objects
private static string      sLastPacket; // last package while communicating
private static int                iOID; // the object id of the current object
private static int                iTID; // the current transaction id
private static int            iWaitTID;
        static mapping      mVariables; // session variables
        static array           aEvents;
        static int         __connected;
        static int     __downloadBytes;
               int     __last_response;
        static function  downloadStore;

private static mixed          miResult;
private static int           miCommand;

static Thread.Mutex    cmd_mutex =     Thread.Mutex();
static Thread.Mutex    newmut =     Thread.Mutex();
static Thread.Condition cmd_cond = Thread.Condition();
static Thread.Queue      resultQueue = Thread.Queue();
Thread.MutexKey key ;
static Thread.MutexKey newmutkey;
static Thread.Condition    th = Thread.Condition();
static object                                cmd_lock;
static Stdio.File sock = Stdio.File();
string connected_server;
int connected_port;

class SteamObj 
{
  private static int oID; 
  private static string identifier = 0;
  private static int cl = 0;
  private static int(0..1) nowait;
  private static mapping(string:function) functions=([]);
  
  int get_object_id() {
    return oID;
  }

  object get_environment() {
    return send_command(COAL_COMMAND, ({ "get_environment" }));
  }

  int get_object_class() {
    if ( cl == 0 ) {
      int wid = iWaitTID;
      int id = set_object(oID);
      mixed res = send_command(COAL_COMMAND, ({ "get_object_class" }));
      if ( intp(res) )
	  cl = res;
      set_object(id);
      iWaitTID = wid;
    }
    return cl;
  }
  int status() {
    return 1; //PSTAT_SAVE_OK
  }

  string get_identifier() {
    if ( !stringp(identifier) ) {
      int wid = iWaitTID;
      int id = set_object(oID);
      identifier = send_command(COAL_COMMAND, ({ "get_identifier" }));
      set_object(id);
      iWaitTID = wid;
    }
    return identifier;
  }

  void create(int id) {
    oID = id;
  }

  int no_wait(void|int(0..1) _nowait)
  {
    if(!zero_type(_nowait) && nowait == !_nowait)
    {
      nowait=!!_nowait;
      return !nowait;
    }
    else
      return nowait;
  }

  string function_name(function fun)
  {
    return search(functions, fun);
  }

  string _sprintf()
  {
    mixed describe="";
    catch{ describe=`->("describe")(); };
    string format = "";
    if ( stringp(connected_server) ) format += "%s:";
    else format += "%O:";
    if ( intp(connected_port) ) format += "%d/";
    else format += "%O/";
    if ( stringp(describe) ) format += "%s";
    else format += "%O";
    return sprintf( format, connected_server, connected_port, describe );
  }

  function `->(string fun) 
  {
    if(::`->(fun))
      return ::`->(fun);
    else
    {
      if ( fun == "exec_code" )
	return 0;
      else if ( fun == "serialize_coal" )
	return 0;
      if(!functions->fun)
        functions[fun]=lambda(mixed|void ... args)
                       { 
                         return send_cmd(oID, fun, args, nowait); 
                       };
      return functions[fun];
    }
  }
  function find_function(string fun) {
    if(!functions->fun)
      functions[fun]=lambda(mixed|void ... args)
		     { 
		       return send_cmd(oID, fun, args, nowait); 
		     };
    return functions[fun];
  }
};


/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
int set_object(int|object id)
{
    int oldID = iOID;

    if ( objectp(id) )
	iOID = id->get_object_id();
    else
	iOID = id;
    return oldID;
}

/**
 *
 *  
 * @param 
 * @return 
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
static object find_obj(int id)
{
    if ( !mObjects[id] ) {
	mObjects[id] = SteamObj(id);
	//werror("Created:"+master()->describe_object(mObjects[id])+"\n");
    }
    return mObjects[id];
}

object find_object(int id) { return find_obj(id); }


/**
 *
 *  
 * @param 
 * @return 
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
int connect_server(string server, int port)
{
    iTID = 1;
    iOID = 0;

    sLastPacket     = "";
    __downloadBytes =  0;
    mVariables      = ([ ]);
    mObjects        = ([ ]);
    aEvents         = ({ });
    
    open_socket();
    set_blocking();
    if ( connect(server, port) ) {
	MESSAGE("Connected to " + server + ":"+port +"\n");
	connected_server=server;
	connected_port=port;
//  SSL.sslfile ssl = SSL.sslfile(socket, SSL.context());
	__last_response = time(); // timestamp of last response	
	__connected = 1;
	set_buffer(65536, "r");
	set_buffer(65536, "w");
	set_blocking();
	thread_create(read_thread);
	return 1;
    }
    return 0;
}

int connect_server_sock(string server, int port)
{
    iTID = 1;
    iOID = 0;

    sLastPacket     = "";
    __downloadBytes =  0;
    mVariables      = ([ ]);
    mObjects        = ([ ]);
    aEvents         = ({ });
    
    if ( socket_connect(server, port) ) {
  MESSAGE("Connected to " + server + ":"+port +"\n");
  connected_server=server;
  connected_port=port;
  __last_response = time(); // timestamp of last response 
  __connected = 1;
  return 1;
    }
    return 0;
}

void create()
{
}

static int write(string str)
{
    __last_response = time();
    return ::write(str);
}


/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
int h=0;
void read_callback(object id, string data)
{
    i++;
    Stdio.File a = Stdio.File();
    a->open("/home/trilok/Desktop/my_gsoc_work/new/sTeam/spm/read_callback","wca");
    __last_response = time();
    a->write("----------------"+i+"-------------------\n");
    a->write("data is : "+data+"\n");
    if ( functionp(downloadStore) ) {
  a->write("downloadStore is a function\n");
	mixed err = catch {
	    downloadStore(data);
	};
	__downloadBytes -= strlen(data);
	if ( __downloadBytes <= 0 ) {
	    downloadStore(0);
	    downloadStore = 0; // download finished
	}
	return;
    }
    sLastPacket += data;
    if ( __downloadBytes > 0 ) {
	if ( __downloadBytes <= strlen(sLastPacket) ){
      a->write(sLastPacket+" last packet written in resultQueue\n");
	    resultQueue->write(sLastPacket);
      a->write(sLastPacket);
      }
	return;
    }
//    a->write("slastpacket is  "+sLastPacket+"\n");
    mixed res = receive_binary(sLastPacket);
//    a->write("res is %O\n",res);
    if ( arrayp(res) ) {
	int tid = res[0][0];
	int cmd = res[0][1];

	sLastPacket = res[2];
	if ( tid == iWaitTID ) {
	    miResult = res[1];
	    miCommand = res[0][1];
//      a->write("%O : written in resultQueue\n",miResult);
//      miResult = res[1];
      a->write("written now");
	    resultQueue->write(miResult);
	}
    }
}

string download(int bytes, void|function store) 
{
    // actually the last command should have been the upload response,
    // so there shouldnt be anything on the line except events
    // which should have been already processed
    // everything else should be download data
    string data;
    Stdio.File a = Stdio.File();
    a->open("/home/trilok/Desktop/my_gsoc_work/new/sTeam/spm/download","wca");
    __downloadBytes = bytes;
    a->write("inside here\n");
    if ( functionp(store) ) {
	data = copy_value(sLastPacket[..bytes]);
	__downloadBytes -= strlen(data);
	if ( strlen(data) > 0 )
	    store(data);
	if ( __downloadBytes <= 0 ) {
	    store(0);
	    return "";
	}
  a->write("downloadStore is now = store\n");
	downloadStore = store;
	return "";
    }
    downloadStore = 0;

    if ( strlen(sLastPacket) >= bytes ) {
	data = copy_value(sLastPacket[..bytes]);
	if ( bytes > strlen(sLastPacket) )
	    sLastPacket = sLastPacket[bytes+1..];
	else
	    sLastPacket = "";
	__downloadBytes = 0;
	return data;
    }

    miResult = resultQueue->read();
    a->write(miResult+" read from resultQueue\n");
    data = copy_value(sLastPacket[..bytes]);
    if ( strlen(sLastPacket) > bytes )
	sLastPacket = sLastPacket[bytes+1..];
    else
	sLastPacket = "";
    __downloadBytes = 0;
    return data;
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
void handle_error(mixed err)
{
    throw(err);
}
int co = 0;
/**
 *
 *  
 * @param 
 * @return 
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
mixed send_command(int cmd, array(mixed) args, int|void no_wait)
{
//    newmutkey = newmut->lock(1);
    co++;
    Stdio.File o = Stdio.File();
    o->open("/home/trilok/Desktop/my_gsoc_work/new/sTeam/spm/random","wca");
//    o->write("inside send_command\n");
    o->write("----------------------- "+co+"-----------------------\n");
    //o->close();
    if ( !no_wait ) iWaitTID = iTID;
    aEvents  = ({ });
    
    string msg = coal_compose(iTID++, cmd, iOID, 0, args);
    string nmsg = copy_value(msg);
//    o->write("sending message now\n");
    o->write("nmsg is : "+nmsg+"\n");
    send_message(nmsg);
//    o->write("sent message\n");
    if ( no_wait ) return 0;
//    o->write("Reading  result\n");
//    o->write("size : "+resultQueue->size()+"\n");
//    sock->connect("127.0.0.1",1999);
//    string strs = sock->read();
//    o->write(strs);
    mixed result=0;
/*    if(cmd==14)
    {
      result = resultQueue->try_read();
      return result;
    } */
//    int start_time = time();
//    while((result=resultQueue->try_read())==0)
//    { 
//      if(time()-start_time > 120)
//     {
//        o->write("EXCEEDED TIME LIMIT\n");
//        return 0;
//      }
  //   }
    
    Thread.Thread(check_thread); 
    result = resultQueue->read();
    th->signal();
    newmutkey = 0;
//    mixed result = 0;
    o->write("result is : %O\n",result);
    if ( miCommand == COAL_ERROR ) {
	handle_error(result);
    }
    return result;
}

static Stdio.File out = Stdio.File();
//out->open("/home/trilok/Desktop/my_gsoc_work/new/sTeam/spm/thread","wca");
void check_thread()
{
//    out->write("inside check_thread at "+time()+"\n");
    out->open("/home/trilok/Desktop/my_gsoc_work/new/sTeam/spm/thread","wca");
    out->write("inside check_thread at "+time()+"\n");
    int start_time = time();
    th->wait(cmd_mutex->lock(), 10);
    if((time()-start_time) >=10){
      out->write("\nsTeam connection lost\n");
      resultQueue->write("sTeam connection lost.");
      out->write("size : "+resultQueue->size());
    }
}
/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
mixed send_cmd(object|int obj, string func, mixed|void args, void|int no_wait)
{
    int oid = set_object(obj);
    if ( zero_type(args) )
	args = ({ });
    else if ( !arrayp(args) )
	args = ({ args });
    
    mixed res = send_command(COAL_COMMAND, ({ func, args }), no_wait);
    set_object(oid);
    return res;
}

/**
 *
 *  
 * @param 
 * @return 
 * @author Thomas Bopp (astra@upb.de) 
 * @see 
 */
mixed 
login(string name, string pw, int features, string|void cname, int|void novars)
{
    Stdio.File a = Stdio.File();
    a->open("/home/trilok/Desktop/my_gsoc_work/new/sTeam/spm/login_d","wca");
    if ( !stringp(cname) )
	cname = "steam-pike";
    
    mixed loginData="hi";
    mixed tempData;
    a->write("before while\n");
  while(loginData=="sTeam connection lost."||loginData=="hi")
  { a->write("inside while\n"); 
    if ( features != 0 )
	loginData =send_command(COAL_LOGIN, ({ name, pw, cname, features, __id }));
    else
	loginData =
	    send_command(COAL_LOGIN,({ name, pw, cname,CLIENT_FEATURES_ALL, __id}));
    tempData = loginData;
    a->write("logindata : %O",tempData);
  }
    if ( arrayp(loginData) && sizeof(loginData) >= 9 ) {
	mVariables["user"] = iOID;
	foreach ( indices(loginData[8]), string key ) {
	    mVariables[key] = loginData[8][key];
	}
	mVariables["rootroom"] = loginData[6];
	sLastPacket = "";
	if ( novars != 1 ) {
	    foreach ( values(loginData[9]), object cl ) {
		set_object(cl->get_object_id());
		mVariables[send_cmd(cl,"get_identifier")] = cl;
	    }
	}
  a->write("returning name\n");
	return name;
    }
    a->write("returning 0\n");
    return 0;
}

mixed logout()
{
    werror("logout()!!!\n\n");
    __connected = 0;
    write(coal_compose(0, COAL_LOGOUT, 0, 0, 0));
}


void was_closed()
{
    resultQueue->write("");
    ::was_closed();
}


void write_error2file(mixed|string err, int recursive) {

    Stdio.File error_file;
    string             path;
    array(string) directory;
    int file_counter =0;
    int found=0;
    path = getcwd();
    directory = get_dir(path);
    while (found==0){
        int tmp_found=1;
        tmp_found=Stdio.exist(path+"/install_error."+file_counter);
        if (tmp_found==1){
            file_counter = file_counter + 1;
        }
        else{
            found = 1;
        }
    }

    if (recursive==1)
        file_counter = file_counter -1;
    error_file=Stdio.File (path+"/install_error."+file_counter ,"cwa");
    if (stringp (err)){
        error_file->write(err);
    }
    if(arrayp(err)){
        foreach(err, mixed error){
            if ( stringp(error) || intp(error) )
                error_file->write((string)error);
            else if ( objectp(error) )
                error_file->write("<object...>\n");
            else if ( arrayp(error) ){
                write_error2file(error,1);
            }
        }
    }
    if (recursive!=0)
        error_file->close();
}



