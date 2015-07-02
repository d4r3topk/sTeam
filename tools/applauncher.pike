 Copyright (C) 2000-2004  Thomas Bopp, Thorsten Hampel, Ludger Merkens
 * Copyright (C) 2003-2004  Martin Baehr
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
 * $Id: applauncher.pike,v 1.1 2008/03/31 13:39:57 exodusd Exp $
 */

constant cvs_version="$Id: applauncher.pike,v 1.1 2008/03/31 13:39:57 exodusd Exp $";

string file;
object newfileobj;

void upload(object editor, string file, int last_mtime, object obj, object xslobj, function|void exit_callback)
{
//  write("file is "+file+"\n");
  int exit_status = editor->status();
  object new_stat = file_stat(file);
  int new_mtime;
  string newcontent;
//  write("obj is %O\n",obj);
  string oldcontent = obj->get_content();
//  write("Came in upload\n");
  if (!new_stat)
    send_message(sprintf("%s is gone!", file));

  if (new_stat && new_stat->mtime > last_mtime)
  {
//    write("get new content\n");
    new_mtime = new_stat->mtime;
    newcontent = Stdio.read_file(file);
    if (!stringp(newcontent))
      send_message(sprintf("failed to read %s", file));
  }

  if (stringp(newcontent) && newcontent != oldcontent && oldcontent!="sTeam connection lost.")
  {
//    write("set new content\n");
    last_mtime=new_mtime;
    mixed result=obj->set_content(newcontent);
    string message=sprintf("%O: upload: %O", obj, result);
    send_message(message);
    if (xslobj)
    {
      result=xslobj->load_xml_structure();
      message=sprintf("%O: load xml struct: %O", xslobj, result);
      send_message(message);
    }
  }
  if(oldcontent=="sTeam connection lost.")
  {
//      remove_call_out(upload);
//      sleep(2);
//      write("slept for 2. checking oldcontent\n");
//      oldcontent =  obj->get_content();
//      write("oldcontent is "+oldcontent+"\n");
//      write("trying to set newfileobj\n");
      if(newfileobj)
        obj = newfileobj;
  }

  if (exit_status != 2)
    call_out(upload, 1, editor, file, new_mtime, obj, xslobj, exit_callback);
  else if (exit_callback)
  {
    exit_callback(editor->wait());
    exit(1);  
  }
}


void update(object obj)
{
//  write("object recieved is %O\n",obj);
  newfileobj = obj;
//  write("newfileobj is %O\n",newfileobj);
}

array edit(object obj)
{
//  write("came in edit function\n");
#if constant(Crypto.Random)
  string dir="/tmp/"+(MIME.encode_base64(Crypto.Random.random_string(10), 1)-("/"))+System.getpid();
#else
  string dir="/tmp/"+(MIME.encode_base64(Crypto.randomness.pike_random()->read(10), 1)-("/"))+System.getpid();
#endif
  string filename=obj->get_object_id()+"-"+obj->get_identifier();

  mkdir(dir, 0700);
  string content=obj->get_content();
  //werror("%O\n", content);
  Stdio.write_file(dir+"/"+filename, content||"", 0600);
  
  //array command=({ "screen", "-X", "screen", "vi", dir+"/"+filename });
  //array command=({ "vim", "--servername", "VIM", "--remote-wait", dir+"/"+filename });
  array command=({ getenv("EDITOR")||"vim", dir+"/"+filename });
  object editor=Process.create_process(command,
                                     ([ "cwd":getenv("HOME"), "env":getenv(), "stdin":Stdio.stdin, "stdout":Stdio.stdout, "stderr":Stdio.stderr ]));
//  write("editor got initialized\n");
return ({ editor, dir+"/"+filename });
} 

int send_message(string message)
{
  if (getenv("STY"))
      Process.create_process(({ "screen", "-X", "wall", message }));
  else if (getenv("TMUX"))
      Process.create_process(({ "tmux", "display-message", message }));
  else
      werror("%s\n", message);
}

int applaunch(object obj, function exit_callback)
{
//  write("came in applaunch\n");
//  write("obj is %O\n",obj);
  object xslobj;
  if(obj->get_identifier()[sizeof(obj->get_identifier())-8..]==".xsl.xml")
  {
    string xslname=
      obj->get_identifier()[..sizeof(obj->get_identifier())-9]+ ".xsl";
    xslobj=obj->get_environment()->get_object_byname(xslname);
  }
  object editor;
  string file;
//  write("before calling edit\n");
  [editor, file]=edit(obj);
//write("after calling  edit\n");
//  mixed status;
  //while(!(status=editor->status()))

  call_out(upload, 1, editor, file, file_stat(file)->mtime, obj, xslobj, exit_callback);
//  write("after calling upload\n");
//  signal(signum("SIGINT"), prompt);
//  return upload(editor, file, file_stat(file)->mtime, obj, xslobj, exit_callback);
  return -1;
}
