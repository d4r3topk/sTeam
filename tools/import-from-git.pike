#!/usr/local/lib/steam/bin/steam

#include "/usr/local/lib/steam/server/include/classes.h"
inherit .client;
inherit "/home/trilok/Desktop/my_gsoc_work/new/sTeam/tools/applauncher.pike";
#define OBJ(o) _Server->get_module("filepath:tree")->path_to_object(o)

constant cvs_version="$Id: import-from-git.pike.in,v 1.1 2015/06/08 14:19:52 martin Exp $";

object _Server;
object file;
int count = 0;
mapping items=([]);
mapping steam_file_vers=([]);
mapping steam_number_vers=([]);
mapping to_import = ([]); //
mapping versions = ([]);
int check=0;
Stdio.File o = Stdio.File();
int main(int argc, array(string) argv)
{
    options=init(argv);
    o->open("/home/trilok/steam2/sTeam/tools/t1","wct");
    array opt = Getopt.find_all_options(argv,aggregate(
    ({"update",Getopt.NO_ARG,({"-U","--update"})}),
    ({"restart",Getopt.NO_ARG,({"-R","--restart"})}),
    ({"force",Getopt.NO_ARG,({"-F","--force"})}),
    ({"bestoption",Getopt.NO_ARG,({"-B","--bestoption"})}),
    ({"append",Getopt.NO_ARG,({"-A","--append"})})));
    options += mkmapping(opt[*][0], opt[*][1]);
    options->src = argv[-2];    //~/tmp/hello
    options->dest = argv[-1];   //home_doc
    _Server=conn->SteamObj(0);
    import_from_git(options->src, options->dest);
    return 0;
}
int commitcount = 0;
void import_from_git(string from, string to)
{
    int a=0;
    int newfile_flag=0;
    int newfile_count=0;
    int isrootroom = 0;
    int flag_check=0;
    write("inside import-from-git function\n");
    int i;
    if(check_steam_path(to)&&check_from_path(from))
    {
      if(to[-1]=='/' && sizeof(to)!=1)    //remove last "/"
        to=to[ .. (sizeof(to)-2)];
      if(from[-1]=='/')    //remove last "/"
      from=from[ .. (sizeof(from)-2)];
      string curfrom=from;
      string curto = to;
      o->write("TO is "+to+"\n");
/*      if(OBJ(to)->query_attribute("OBJ_PATH")=="root-room")  //FIXME dont compare to root-room. can be something else for someone else.
        isrootroom = 1;*/
       write("steam path and from path are correct\n");
       int num_versions = get_num_versions(from);
       write("inside main : num_versions : "+(string)num_versions+"\n");
        o->write("GIT COMMITS - %O\n",num_versions);
      array(string) all_files = get_all_affected(from,num_versions);
      if(!isrootroom||isrootroom)
      {
        o->write("not root room\n");
        if(options->force)
          check =1;   //This directly commits everything starting from first commit
        for(int i=1; i<=num_versions; i++) //To use 1 or 0?
        {
          o->write("------------\nChecking "+(string)i+" commit\n---------------\n");
          if(flag_check==1)
            break;
          commitcount++; //replace this with i itself
          array(string) files = get_commit_files(from, i);
//FIXME for empty commit handling
        if(check==0)
        {
          if(commitcount!=1 && sizeof(files)==0) //empty commit check in middle
          {
              check_content(curto,curfrom,1);
              if(equal(versions,steam_number_vers)) //version count from git matches sTeam version count
              {
                o->write("End checking now(from empty). versions = steam_file_vers\n");
                o->write("I FROM EMPTY IS "+i+"\n");
                check = 1;
              }
          }
          else
            diff=0;
//till here - maybe embee will ask to remove this
          files = files - ({""});
          o->write("-Found files - %O\n",files);
          for(int j=0; j<sizeof(files); j++)
          {
            o->write("--Checking "+files[j]+"\n");
            curfrom = from+"/"+files[j];
            curto = to+"/"+files[j];  //need to check whether this path exists, if not create files[j] inside to. Don't create now though. Only after checking all files.
            o->write("curfrom - "+curfrom+"\ncurto - "+curto+"\n");
            if(!OBJ(curto)) //FIXME autocreate containers/files. -- this is done when to_import is iterated. DONE.
            {
              write("Adding to to_import\n");
              to_import = to_import + ([ curto:(["gitpath":curfrom, "commitcount":commitcount, "empty":0]) ]); //this is a file not in sTeam, so handle creating it while iterating through to_import
              newfile_flag = 1;
              newfile_count++;
            }
          if(newfile_flag!=1)
          {  
            int c = check_content(curto, curfrom,0);
            if(!c)
            {
              flag_check=1;
              o->write("---Doesn't exist\n");
              break;
            }
            o->write("---Exists\n");
          }
          newfile_flag=0;
          if(sizeof(versions)==0 && sizeof(steam_number_vers)==0) //totally new folders, copying all the content.
          {
            o->write("Both are empty, so  check=1\n");
            check=1;
          }
            if((sizeof(versions)==sizeof(all_files)-newfile_count)) //same number of files encountered.
            {
              o->write("sizeof versions = all_files\n");
              o->write("versions are %O\n",versions);
              o->write("steam_number_vers are %O\n",steam_number_vers);
              if(equal(versions,steam_number_vers)) //version count from git matches sTeam version count
              {
                o->write("End checking now. versions = steam_file_vers\n");
                check = 1;
                o->write("I IS "+i+"\n");
                break;
              }
            }
          }
        }
          //Starting import now.
      else if(check==1) //Force option directly comes here - second condition; if there is nothing to import, from last check it comes here, and tries to set OBJ(curto) but that we dont want
      {
        if(!options->force&&count==0)
        {
          write("Histories match.\n");
          count++;  //so that this gets printed only once.
        }
        if(sizeof(to_import)>0)
        {
          handle_to_import(to_import);
        }
// FIXME : Look at this(manually set to empty! will user do this?)
        if(commitcount!=1 && sizeof(files)==0)
        {
          string content = git_version_content(curfrom, i , 1);
          OBJ(curto)->set_content(content);
        }

        for(int j=0; j<sizeof(files); j++)
          {
            o->write("setting content "+files[j]+"\n");
            curfrom = from+"/"+files[j];
            curto = to+"/"+files[j];
            if(!OBJ(curto))
            {
              o->write("creating steam path : "+curto+"\n");
              check_steam_path(dirname(curto)); //only creates containers
              int a = create_document(basename(curto), dirname(curto));
              if(!a){
                o->write("SOME ERROR WHILE CREATING DOCUMENT\n");
                break;
              }
            }

            string content = git_version_content(curfrom, i, 0);
            OBJ(curto)->set_content(content);
            o->write("curfrom leaving is : "+curfrom+"\n");
          }
      }
      if(flag_check==1)
      {
        write("Histories don't match. Import Failed\n");
        break;
      }
    }
    if(sizeof(to_import)>0) //if last commit is the last in sTeam, then we need to import all to_import. This check is done, so that to_import changes are imported.
      handle_to_import(to_import);
    
  }
       
/*       array steam_history = get_steam_versions(to);
        o->write("STEAM HISTORY\n%O\n",steam_history);
      if(options->bestoption)
      {
          string best = show_bestoption(from, to, steam_history, num_versions);
          write("Best option : "+best+"\n");
      }
      else
      {
       if(options->append)
        a = handle_append(from, to, steam_history, num_versions);
       else if(options->force)
        a = handle_force(from, to, num_versions);
       else
        a = handle_normal(from, to, 1, steam_history, num_versions);

        if(a)
        {
          write("Succesfully imported\n");
        }
        else
        {
          write("import failed\n");
        }
      }
*/
    }
}

void handle_to_import(mapping toimport)
{
  foreach(toimport; string steampath; mapping gitarr)
  {
    if(!OBJ(steampath))
    {
      check_steam_path(dirname(steampath)); //only creates containers
      int a = create_document(basename(steampath), dirname(steampath));
      if(!a)
      {
        o->write("SOME ERROR WHILE CREATING DOCUMENT\n");
        break;
      }
    }
    object steamobj = OBJ(steampath);
    steamobj->set_content(git_version_content(gitarr->gitpath, gitarr->commitcount, gitarr->empty));
    write("setting content for "+steampath+"\n");
  }
  to_import = ([ ]); //this one is the global mapping set to empty
}


array get_steam_versions(string steampath)
{
  object obj = OBJ(steampath);
  mapping versions = obj->query_attribute("DOC_VERSIONS");
  if (!sizeof(versions))
  {
    versions = ([ 1:obj ]);
  }
  array this_history = ({});
  foreach(versions; int nr; object version)
  {
    this_history += ({ ([ "obj":version, "version":nr, "time":version->query_attribute("DOC_LAST_MODIFIED"), "path":obj->query_attribute("OBJ_PATH") ]) });
  }
  sort(this_history->version, this_history);
  if(sizeof(versions)>1)
      this_history += ({ ([ "obj":obj, "version":this_history[-1]->version+1, "time":obj->query_attribute("DOC_LAST_MODIFIED"), "path":obj->query_attribute("OBJ_PATH") ]) });
  return this_history;
}


int check_from_path(string path)
{
  if(path[-1]=='/')    //remove last "/"
      path=path[ .. (sizeof(path)-2)];
  Stdio.File output = Stdio.File();
  Process.create_process(({"git", "rev-parse", "--show-cdup"}), ([ "env":getenv(), "cwd":path , "stdout":output->pipe() ]))->wait();
  string result = output->read();
  o->write("CHECK_FROM_PATH - "+result+"\n");
  o->write("size of ^^ is %O\n",sizeof(result));
  if(sizeof(result)==1)
    return 1;
  else
    return 0;
  return 0;
/*
  string dir,filename;

  write("Came inside check_from_path\n");
  if(Stdio.exist(path))
  {
    write("from path exists\n");
    dir = dirname(path);
    filename = basename(path);
    Stdio.File output = Stdio.File();
    Process.create_process(({ "git", "rev-parse", "--is-inside-work-tree"}), ([ "env":getenv(), "cwd":dir , "stdout":output->pipe() ]))->wait();
    string result = output->read();
    if(result)
    {
      write("output is : "+result+"\n"+"returning 1\n");
      return 1;
    }
    else
    {
      write("output is :"+result+"\n"+"returning 0\n");
      return 0;
    }
  }
  return 0;
*/
}


int check_steam_path(string path)
{
  if(path=="/")
      return 1;
  if(path[-1]=='/')    //remove last "/"
      path=path[ .. (sizeof(path)-2)];
  int j=0;
  int i=0;
  string cur_path;
  array(string) test_parts;
  object cont;
  int num_objects_create=0;
  int res=0;
  array(string) parts = path/"/";
//  parts = parts-({""});  //removing all blanks out
//dont need it mostly  if(sizeof(parts)==4 && parts[1]=="home" && parts[3]=="") 

/* DONT NEED THIS CHECK AS PATHS ARE GOING TO CHANGE
-----
  if(sizeof(parts)==3 && parts[1]=="home") // /home/ and /home/somefile not allowed
  {
    if(path!="/home/" && OBJ(path)->get_class()!="Room")
      return 0;
    else if(path=="/home/")
      return 0;
  }
  else if(sizeof(parts)==2 && parts[1]=="home") // /home not allowed
    return 0;
-----
*/
  parts = parts-({""});  //removing all blanks out
  cur_path = path;

  for(j=(sizeof(parts)-1); j>=0; j--)
  {
    o->write("Checking path : "+cur_path+"\n");
    cont = _Server->get_module("filepath:tree")->path_to_object(cur_path,true);
    if(cont||(cur_path==""))  //cur_path check for root-room
    {
      //CHANGE checking for /home/
        if((OBJ(cur_path)->get_object_class() & CLASS_MODULE) && (sizeof(parts)==1||sizeof(parts)==2))  //checking whether inside /home/
          return 0;

        o->write("Got correct path as : "+cur_path+"\n");
        test_parts=(cur_path/"/")-({""});
        if(test_parts!=parts)
        {
            num_objects_create = sizeof(parts)-sizeof(test_parts);
            res=create_object(cur_path, parts, num_objects_create);
        }
        o->write("returning the object from check_steam_path\n");
        return 1;
    }
    else
    {
        if((sizeof(parts)==1)&&(parts[0]!="home")) //FIXME home should be taken out
        {
          res = create_object("/", parts, 1);
          return 1;
        }
    o->write("subtracting "+parts[j]+"\n");
//    cur_path = cur_path-("/"+parts[j]);  //this would fail for "/x12/x1"-"/x1"
    cur_path = cur_path[ ..sizeof(cur_path)-1-sizeof(parts[j])]; //replaces the above
    o->write("cur_path is now "+cur_path+"\n");
    }
  }
 o->write("returning 0 from check_steam_path\n");
  return 0;
}

int create_object(string path, array(string) parts, int num)
{
    if(path[-1]=='/' && sizeof(path)!=1)    //remove last "/", but take care for only '/' (root room)
      path=path[ .. (sizeof(path)-2)];
    int i=0;


    for(i=num; i>0; i--)
    {
/* CHANGE Dont need to create document for last part. TO path will always be a folder, no matter what.

      if(i==1 && !fromfolder)  //CHANGE need to have a fromfolder var for specifyinh whether from path is a folder.
      {
        string name = parts[i*-1];
        mapping map = (["url":path+"/"+name, "mimetype":"text/plain"]);
        object doc = document_factory->execute(map);
        if(doc)
        {
          doc->set_attribute("OBJ_DESC", "from import-from-git");
          return 1;
        }
        else
          return 0;
      }

      else
      {
*/
        string container_name = parts[i*-1];
        int check = create_container(container_name, path);
        if(check==1)
          path=path+"/"+parts[i*-1];
        else
          return 0;
//    }
    }
    return 1;
}

int exists(string steampath) //checks a steam path exists or not
{
  mixed error = catch{
      if(OBJ(steampath))
        return 1;
      else
        return 0;
  };
  return 0;
  return 0;
}

string get_steam_content(string steampath, int ver) //get the steam file's specific version's content
{
  o->write("----INSIDE get_steam_content\n");
  o->write("steam path : "+steampath+"\n");
  array steam_h=({});
  object obj = OBJ(steampath);
  o->write("steam object : %O\n",obj);
  if(!steam_file_vers[steampath])
  {
    o->write("Not there in steam_file_vers. Adding now\n");
    mapping versions = obj->query_attribute("DOC_VERSIONS");
    o->write("versions : %O\n",versions);
    if (!sizeof(versions))
    {
      versions = ([ 1:obj ]);
    }
   array this_history = ({});
    foreach(versions; int nr; object version)
   {
     this_history += ({ ([ "obj":version, "version":nr, "time":version->query_attribute("DOC_LAST_MODIFIED"), "path":obj->query_attribute("OBJ_PATH") ]) });
   }
   sort(this_history->version, this_history);
   if(sizeof(versions)>=1)
       this_history += ({ ([ "obj":obj, "version":this_history[-1]->version+1, "time":obj->query_attribute("DOC_LAST_MODIFIED"), "path":obj->query_attribute("OBJ_PATH") ]) });
   steam_file_vers = steam_file_vers + ([ steampath:this_history ]);
   steam_number_vers = steam_number_vers + ([ steampath:obj->query_attribute("DOC_VERSION") ]);
    steam_h = this_history;
  }
  else
  {
    steam_h = steam_file_vers[steampath];
    o->write("Already there in steam_file_vers.\n");
  }
  o->write("this history length :"+(string)sizeof(steam_h)+"\n");
  o->write("Checking "+(string)(ver-1)+" now\n");
  o->write("xxxxxxx get_steam_content xxxxxxx\n");
  return steam_h[ver-1]->obj->get_content();
}
//Look here
array(string) get_all_affected(string gitpath, int count)
{
  Stdio.File output = Stdio.File();
  Process.create_process(({ "git", "show", sprintf("%s=%s","--pretty","format:"), "--name-only","-"+(string)count }), ([ "env":getenv(), "cwd":gitpath , "stdout":output->pipe() ]))->wait();
  string result = output->read();
  array arr = result/"\n";
  arr = Array.uniq(arr)-({""});
  o->write("all affected are %O\n", arr);
  return arr;
}

array(string) get_commit_files(string gitpath, int ver) //returns list of files associated with a commit
{
  if(gitpath[-1]=='/')    //remove last "/"
      gitpath=gitpath[ .. (sizeof(gitpath)-2)];

  int total = get_num_versions(options->src);
  string vers=(string)(total-(ver-1)-1);
  Stdio.File output = Stdio.File();
  Process.create_process(({ "git", "show", sprintf("%s=%s","--pretty","format:"), "--name-only","HEAD~"+vers }), ([ "env":getenv(), "cwd":gitpath , "stdout":output->pipe() ]))->wait();
  string result = output->read();
  write("result is : %O\n",(result/"\n")-({""}));
  o->write("result is : %O\n",(result/"\n")-({""}));
  return  (result/"\n")-({""});
}

int create_document(string name, string path) //only for text/plain right now; path is where the object has to be created
{
  if(path[-1]=='/' && sizeof(path)!=1)    //remove last "/"
      path=path[ .. (sizeof(path)-2)];
  object document_factory = _Server->get_factory("Document");
  mapping map = (["url":path+"/"+name, "mimetype":"text/plain"]);
  object doc = document_factory->execute(map);
  if(!doc)
    return 0;
  doc->set_attribute("OBJ_DESC", "from import-from-git");
  return 1;
}

int create_container(string name, string path)
{
  if(path[-1]=='/' && sizeof(path)!=1)    //remove last "/"
      path=path[ .. (sizeof(path)-2)];
  object container_factory = _Server->get_factory("Container");
  object moveloc = OBJ(path);
  object mycont = container_factory->execute((["name":name]));
  if(mycont)
  {
    mycont->move(moveloc);
    mycont->set_attribute("OBJ_DESC","from import-from-git");
  }
  else
    return 0;
  return 1;
}

int get_num_versions(string path)
{
  o->write("GET_NUM_VERSIONS\n");
  if(path[-1]=='/')    //remove last "/"
      path=path[ .. (sizeof(path)-2)];
  Stdio.File output = Stdio.File();
//  write("filename for get_num_versions is "+filename+"\n");
  Process.create_process(({ "git", "rev-list", "HEAD", "--count" }), ([ "env":getenv(), "cwd":path , "stdout":output->pipe() ]))->wait();
  string result = output->read();
  o->write("number of commits : "+result+"\n");
  return (int)result;
}

int check_content(string steampath, string gitpath, int wasempty)
{
  o->write("---INSIDE check_content\n");
  int version = get_version(steampath);
  versions[steampath] = versions[steampath] + 1;
  version = get_version(steampath);
  if(steam_number_vers[steampath])
    if(version>steam_number_vers[steampath])
    {
      o->write("ADDING "+steampath+" IN TO_IMPORT\n");
      to_import = to_import + ([ steampath:(["gitpath":gitpath, "commitcount":commitcount, "empty":wasempty]) ]);
      return  2;
    }
  o->write("version : "+(string)version+"\n");
  string gitcontent = git_version_content(gitpath, commitcount, wasempty);
  o->write("---back to check_content\ngit content : "+gitcontent+"\n");
  string steamcontent = get_steam_content(steampath, version);
  o->write("---back to check_content\nsteam content : "+steamcontent+"\n");
  if(gitcontent == steamcontent)
  {
    if(version==steam_number_vers[steampath])
      return 2;
//    o->write("versions["+steampath+"] is "+versions[steampath]+". Incrementing now\n");
//    versions[steampath] = versions[steampath] + 1;
    return 1;
  }
  return 0;
}

int get_version(string steampath)
{
  if(versions[steampath])
    return versions[steampath];
  versions = versions + ([steampath : 0]);
  return 0;
}
int diff = 0;
string git_version_content(string path, int version, int wasempty)
{
//FIXME empty commit handling
    if(wasempty)
    {
      o->write("git empty commit encountered. checking against last content - "+path+"\n");
      diff=diff+1;
      version = version - diff;
    }
//till here - embee may ask to remove this
    o->write("---- INSIDE git_version_content\n");
    //FIXME MIGHT WANT TO ADD the "/" check on options->src
    o->write("ver : "+(string)version+"\n");
    string ver = (string)version;
//    write("total passed is : "+total+"\n");
    int total = get_num_versions(options->src);
    ver=(string)(total-((int)ver-1)-1);
    //all empty commits above should be added to HEAD~ver so that it points to the right commit
    o->write("revised ver : "+ver+"\n");
    if(path[-1]=='/')
       path=path[ .. (sizeof(path)-2)];
    string dir = dirname(path);
    string filename = basename(path);
    o->write("checking content of "+filename+" in "+dir+"\n");
    Stdio.File output = Stdio.File();
    Process.create_process(({ "git", "show", "HEAD~"+ver+":./"+filename }), ([ "env":getenv(), "cwd":dir , "stdout":output->pipe() ]))->wait();
    string result = output->read();
    o->write("Content is "+result+"\n");
    o->write("xxxxxxx git_version_content xxxxxxx\n");
    return result;
}
/*
int handle_append(string from, string to, array steam_history, int num_git_versions)
{
    write("inside handle append\n");
    string scontent = steam_history[sizeof(steam_history)-1]->obj->get_content();
    string gcontent = git_version_content(from,(string)1,num_git_versions);
    write("scontent : "+scontent+"\n");
    write("gcontent : "+gcontent+"\n");
    if(scontent==gcontent)
    {
     int i=0;
     for(i=2;i<=num_git_versions;i++)
     {
      string content = git_version_content(from,(string)i, num_git_versions);
      OBJ(to)->set_content(content);
     }
     return 1;
    }
    return 0;
}


int handle_force(string from, string to, int num_git_versions)
{
    int i=0;
    for(i=1;i<=num_git_versions;i++)
    {
     string content = git_version_content(from,(string)(i), num_git_versions);
     OBJ(to)->set_content(content);
    }
    return 1;
}

int handle_normal(string from, string to, int num, array steam_history, int num_git_versions)
{
  string scontent = steam_history[num-1]->obj->get_content();
//  write("STEAM HISTORY IS : %O\n and number is %d",steam_history,num-1);
  string gcontent = git_version_content(from,(string)(num),num_git_versions);


  if((num>sizeof(steam_history))||((num==1)&&!scontent))   //after successful history, add it to steam. (second condition for object in sTeam with no versions).
  {
    o->write("Start adding now\n");
    int i=0;
    for(i=num;i<=num_git_versions;i++)
    {
     string content = git_version_content(from,(string)(i), num_git_versions);
     OBJ(to)->set_content(content);
    }
    return 1;
  }
  write("Comparing\n");
  write("scontent : "+scontent+"\n");
    o->write("scontent : "+scontent+"\n");
  write("gcontent : "+gcontent+"\n");
    o->write("gcontent : "+gcontent+"\n");
  if(scontent==gcontent)
  {
    write("Equal\n");
      o->write("Equal\n");
    return handle_normal(from, to, num+1, steam_history, num_git_versions);
  }
  else
  {
    write("Not Equal\n");
    write("Exiting from script. Commits and versions dont match\n");
      o->write("Not equal\nCommits and versions dont match\n");
    return 0;
  }
}

string show_bestoption(string from, string to, array steam_history, int num_git_versions)
{
  //CHECKING FOR NORMAL
  int i=0,flag=0;
  string scontent,gcontent;
  for(i=1;i<=sizeof(steam_history);i++)
  {
    scontent = steam_history[i-1]->obj->get_content();
    gcontent = git_version_content(from,(string)i,num_git_versions);
    if(scontent!=gcontent)
    {
        flag=1;
        break;
    }
  }
  if(flag==0)
      return "normal";

  //CHECKING FOR APPEND
  scontent = steam_history[sizeof(steam_history)-1]->obj->get_content();
  gcontent = git_version_content(from,(string)1,num_git_versions);
  if(scontent==gcontent)
      return "append(-A)";
  else  //OTHERWISE FORCE OPTION
      return "force(-F)";
}
*/
