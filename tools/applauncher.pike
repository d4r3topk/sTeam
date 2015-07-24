/* Copyright (C) 2000-2004  Thomas Bopp, Thorsten Hampel, Ludger Merkens
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

object newfileobj;
string content;
int i=1;
int j=1;
int count=0;
string dir;
string debugfile;

//Stdio.File debug_obj = Stdio.File();
void upload(object editor, string file, int last_mtime, object obj, object xslobj, function|void exit_callback)
{
  
  int exit_status = editor->status();
  object new_stat = file_stat(file);
  int new_mtime;
  string newcontent;
  string oldcontent = obj->get_content();  //currently changing 
//    send_message("hello");
  if((content!=oldcontent)&&(oldcontent!=("sTeam connection lost."||""))&&obj&&(i==1))
  {
//    send_message("oldcontent is "+oldcontent+"\n");
    i=0;
    send_message("File changed on server.\n");
//NEED to look here!!!     Stdio.write_file(file, oldcontent||"", 0600);
    last_mtime = new_stat->mtime;
  }
  if (!new_stat)
    send_message(sprintf("%s is gone!", file));

  if (new_stat && new_stat->mtime > last_mtime)
  {
//    write("newstat mtime more\n");
    new_mtime = new_stat->mtime;
    newcontent = Stdio.read_file(file);
//    write("newcontent is "+newcontent+"\n");
    if (!stringp(newcontent))
      send_message(sprintf("failed to read %s", file));
  }

  if (stringp(newcontent) && newcontent != content && oldcontent!="sTeam connection lost.")
  {
//    write("newcontent exists\n");
    last_mtime=new_mtime;
    content = newcontent;
    mixed result=obj->set_content(newcontent);
    string message=sprintf("File saved - upload: %O\n", result);
    send_message(message);
//    Stdio.write_file(dir+"/"+debugfile, "", 0600);
    count=0;
    if (xslobj)
    {
      result=xslobj->load_xml_structure();
      message=sprintf("%O: load xml struct: %O", xslobj, result);
      send_message(message);
    }
  }
  if(oldcontent=="sTeam connection lost.")
  {
    if(j==1){
      send_message("Disconnected\n");
      j--; }
      if(newfileobj){
//        send_message(sprintf("obj is %O\n",obj));
        send_message("Connected back\n");
        obj = newfileobj;
}
  }

  if (exit_status != 2){
    if(count!=1)
    {
    count = 1;
    array errors = obj->get_errors();
    write("writing ---- now\n");
    send_message("-----------------------------------------\n");
    if(errors==({}))
      send_message("Compiled successfully\n");
    else
    {
      foreach(errors, string err)
        send_message(err);
      send_message("Compilation failed\n");
    }
    send_message("-----------------------------------------\n");
    }
    call_out(upload, 1, editor, file, new_mtime, obj, xslobj, exit_callback);
  }
  else if (exit_callback)
  {
    if(count!=1)
    {array errors = obj->get_errors();
    if(errors==({}))
      send_message("Compiled successfully");
    else
    {
      foreach(errors, string err)
        send_message(err);
      send_message("Compilation failed");
    }
    }
    exit_callback(editor->wait());
    exit(1);  
  }
}


void update(object obj)
{
  send_message(sprintf("Inside update : %O\n",obj));
  newfileobj = obj;
}

array edit(object obj)
{
#if constant(Crypto.Random)
  dir="/tmp/"+(MIME.encode_base64(Crypto.Random.random_string(10), 1)-("/"))+System.getpid();
#else
   dir="/tmp/"+(MIME.encode_base64(Crypto.randomness.pike_random()->read(10), 1)-("/"))+System.getpid();
#endif
  string filename=obj->get_object_id()+"-"+obj->get_identifier();
  debugfile = filename+"-disp";
//write("OPENED\n");
//  debug_obj->open(dir+"/"+debugfile,"wct");
//  write("%O\n",debug_obj);
  mkdir(dir, 0700);
  content=obj->get_content();  //made content global, this is content when vim starts and remains same. oldcontent keeps changing in upload function.
  //werror("%O\n", content);
  Stdio.write_file(dir+"/"+filename, content||"", 0600);
  Stdio.write_file(dir+"/"+debugfile, "", 0600);
  array command;
  //array command=({ "screen", "-X", "screen", "vi", dir+"/"+filename });
    string enveditor = getenv("EDITOR");

  if((enveditor=="VIM")||(enveditor=="vim"))
    command=({ "vim","-S", "/home/trilok/Desktop/all_gits/societyserver/sTeam/tools/watchforchanges.vim", "-c", sprintf("split|view %s",dir+"/"+debugfile), dir+"/"+filename });
  else if(enveditor=="emacs")
    command=({ "emacs", "--eval","(add-hook 'emacs-startup-hook 'toggle-window-spt)", "--eval", "(global-auto-revert-mode t)", dir+"/"+filename, dir+"/"+debugfile, "--eval", "(setq buffer-read-only t)", "--eval", sprintf("(setq frame-title-format \"%s\")",obj->get_identifier()) });
  else
    command=({ "vi" , dir+"/"+filename });

  object editor=Process.create_process(command,
                                     ([ "cwd":getenv("HOME"), "env":getenv(), "stdin":Stdio.stdin, "stdout":Stdio.stdout, "stderr":Stdio.stderr ]));
//array command1=({ "vim", "--servername", "MYSERVER", "--remote-send","<Esc>:view "+dir+"/"+debugfile });

//array command1=({ getenv("DISPLAY")||"vim", "--servername", "MYSERVER","--remote-send", "ihello<Esc>"});

//Process.create_process(command1,
//                                     ([ "cwd":getenv("HOME"), "env":getenv(), "stdin":Stdio.stdin, "stdout":Stdio.stdout, "stderr":Stdio.stderr ]));
  return ({ editor, dir+"/"+filename });
} 

int send_message(string message)
{
/*  if (getenv("STY"))
      Process.create_process(({ "screen", "-X", "wall", message }));
  else if (getenv("TMUX"))
      Process.create_process(({ "tmux", "display-message", message }));
  else
      werror("%s\n", message);
*/
//  debug_obj->write_oob(message);
Stdio.append_file(dir+"/"+debugfile, message||"", 0600);
}

int applaunch(object obj, function exit_callback)
{
  object xslobj;
  if(obj->get_identifier()[sizeof(obj->get_identifier())-8..]==".xsl.xml")
  {
    string xslname=
      obj->get_identifier()[..sizeof(obj->get_identifier())-9]+ ".xsl";
    xslobj=obj->get_environment()->get_object_byname(xslname);
  }

  object editor;
  string file;
  [editor, file]=edit(obj);
  mixed status;
  //while(!(status=editor->status()))

  call_out(upload, 1, editor, file, file_stat(file)->mtime, obj, xslobj, exit_callback);

//  signal(signum("SIGINT"), prompt);
  return -1;
}
