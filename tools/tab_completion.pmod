inherit Tools.Hilfe.Evaluator;
inherit Tools.Hilfe;

  mapping myvars = ([ ]);
  object server_fp;
  object mainhandler;
  Stdio.Readline readln = Stdio.Readline(Stdio.stdin);
  Stdio.File o = Stdio.File();
  mapping(string:mixed) constants = constants;  //fetching Evaluator constants

mapping base_objects(Evaluator e)
{
  o->write("variables are : %O\n",e->variables);
  return all_constants() + e->constants + e->variables + myvars;
}
void set_handler(object handler)
{
    mainhandler = handler;
}

void set_server_filepath(object o)
{
  server_fp = o;
}

array(object|array(string)) resolv(Evaluator e, array completable,
                                   void|object base, void|string type)
{
  if (e->variables->DEBUG_COMPLETIONS)
    e->safe_write("resolv(%O, %O, %O)\n", completable, base, type);
  if (!sizeof(completable))
    return ({ base, completable, type });
  o->write("divider 1\n");
  if (stringp(completable[0]) &&
      completable[0] == array_sscanf(completable[0], "%[ \t\r\n]")[0])
    return ({ base, completable[1..], type });
  o->write("divide  2\n");
  if (typeof_token(completable[0]) == "argumentgroup" && type != "autodoc")
    return resolv(e, completable, master()->show_doc(base), "autodoc");
  o->write("divider 3\n");
  int flag2 = 0;
//  array toks = array_sscanf(input,"%s->");
//  if (!base && (completable[0] == "."||toks[0]))
  if(!base && completable[0]==".")
  {
    o->write("divider 4 came inside if\n");
    if (sizeof(completable) == 1)
      return ({ 0, completable, "module" });
    else
    {
      o->write("divider 5\n");
      catch
      {
        // quick and dirty attempt to load a local module
//        string format = "%s->";
//        array toks = array_sscanf(input,format);
/*        if(toks[0])
        {
          o->write("came in object o = "+toks[0]+"\n");
//          o->write("evaluator is %O\n",e);
          o->write("mainhandler is %O\n",mainhandler);
          base = compile_string(sprintf("object o=%s;", toks[0]), "",mainhandler)()->o;
          o->write("base in resolv is : %O\n",base);
          if(base)
              flag2 = 1;
        }
*/
         o->write("object o = "+completable[1]+"\n");
         base=compile_string(sprintf("object o=.%s;", completable[1]), 0)()->o;
         o->write("base in resolv: %O\n",base);
      };
      o->write("divider 6\n");
      if (!base)
        return ({ 0, completable, type });
      o->write("divider 7\n");
      if (objectp(base))
        return resolv(e, completable[2..], base, "module");
      return resolv(e, completable[2..], base);
    }
  }
  o->write("divider 8\n");
  if (!base && sizeof(completable) > 1)
  {
    o->write("divider 8.05\n");
    if (completable[0] == "master" && sizeof(completable) >=2
        && typeof_token(completable[1]) == "argumentgroup")
    {
      o->write("divider 8.1\n");
      return resolv(e, completable[2..], master(), "object");
    }
    o->write("completable[0] is "+completable[0]+"\n");
//    o->write("base_objects(e) is %O\n",base_objects(e));
    if (base=base_objects(e)[completable[0]])
    {
      o->write("divider 8.5\n");
      return resolv(e, completable[1..], base, "object");
    }
    o->write("divider 8.6\n");
    if (sizeof(completable) > 1 
        && (base=master()->root_module[completable[0]]))
      return resolv(e, completable[1..], base, "module");
    o->write("gone for 0\n");
    return ({ 0, completable, type });
  }

  o->write("divider 9\n");
  if (sizeof(completable) > 1)
  {
    object newbase;
    if (reference[completable[0]] && sizeof(completable) > 1)
      return resolv(e, completable[1..], base);
    if (type == "autodoc")
    {
      if (typeof_token(completable[0]) == "symbol"
          && (newbase = base->findObject(completable[0])))
        return resolv(e, completable[1..], newbase, type);
      else if (sizeof(completable) > 2 
            && typeof_token(completable[0]) == "argumentgroup"
            && typeof_token(completable[1]) == "reference")
        return resolv(e, completable[2..], base, type);
      else
        return ({ base, completable, type });
    }
    if (!functionp(base) && (newbase=base[completable[0]]) )
      return resolv(e, completable[1..], newbase, type);
  }
  o->write("came till the end\n");
  return ({ base, completable, type });
}


  array get_resolvable(array tokens, void|int debug)
  {
    
    array completable = ({});
    string tokentype;

    foreach(reverse(tokens);; string token)
    {
      string _tokentype = typeof_token(token);

      if (debug)
        write(sprintf("%O = %s\n", token, _tokentype));

      if ( ( _tokentype == "reference" &&
             (!tokentype || tokentype == "symbol"))
            || (_tokentype == "symbol" && (!tokentype
                 || (< "reference", "referencegroup",
                       "argumentgroup" >)[tokentype]))
            || ( (<"argumentgroup", "referencegroup" >)[_tokentype]
                 && (!tokentype || tokentype == "reference"))
         )
      {
        completable += ({ token });
        tokentype = _tokentype;
      }
      else if (_tokentype == "whitespace")
        ;
      else
        break;
    }

    // keep the last whitespace
    if (arrayp(tokens) && sizeof(tokens) &&
        typeof_token(tokens[-1]) == "whitespace")
      completable = ({ " " }) + completable;
    return reverse(completable);
  }


  void set(mapping vars)
  {
//    werror("vars are : %O\n",myvars);
    myvars = vars;
//    werror("vars are : %O\n",myvars);
  }

  void load_hilferc() {
    if(string home=getenv("HOME")||getenv("USERPROFILE"))
      if(string s=Stdio.read_file(home+"/.hilferc"))
  map(s/"\n", add_buffer);
  }


  array tokenize(string input)
  {
      array tokens = Parser.Pike.split(input);
      if (variables->DEBUG_COMPLETIONS)
          readln->message(sprintf("\n\ntokenize(%O): %O\n\n", input, tokens));
      // drop the linebreak that split appends
      if (tokens[-1] == "\n")
        tokens = tokens[..<1];
      else if (tokens[-1][-1] == '\n')
        tokens[-1] = tokens[-1][..<1];

      tokens = Parser.Pike.group(tokens);
      return tokens;
  }

string input;
  void handle_completions(string key)
  {
    o->open("/home/trilok/Desktop/all_gits/societyserver/sTeam/t1","wct");
//    o->write("KEY IS : "+key+"\n");
    mixed old_handler = master()->get_inhibit_compile_errors();
    HilfeCompileHandler handler = HilfeCompileHandler(sizeof(backtrace()));
    master()->set_inhibit_compile_errors(handler);

    array tokens;
    input = readln->gettext()[..readln->getcursorpos()-1];
    //o->write("INPUT IS "+input+"\n");
    array|string completions;

    mixed error = catch
    {
      tokens = tokenize(input);
      o->write("tokens are %O\n",tokens);
    };
//    o->write("Tokens are : %O\n",tokens);
    int flag = 0;
    if(error)
    {
      o->write("came in first error\n");
      if (objectp(error) && error->is_unterminated_string_error)
      {
        // THE set_attribute and get_attribute TAB COMPLETION IS HEREEEEEEEEEEEEEEE.

        o->write("came in 1-if\n");
        error = catch
        {
          o->write("input is "+input+"\n");
          array toks=({ });
//        string format = "%s->query_attribute(\"%s";
//          array toks = array_sscanf(input,format);
          mixed error5 = catch{
            toks = tokenize(input+"\")");
            o->write("toks is %O\n",toks);
          };
          if(error5==0)
          {
//            object conn = ((program)"debug.pike")();
//            object a;
            o->write("inside toks\n");
            int b = 0;
            b=search(toks,"set_attribute");
            o->write("b with set_attri is %O\n",b);
            if(b!=(sizeof(toks)-2))
            {
             b=search(toks,"query_attribute");
              o->write("b with query_attri is %O\n",b);
            }
            
            if(b==(sizeof(toks)-2))  //because if set/query_attribute is at the end it will be second last token, which is -2
            {
              o->write("came inside b=sizeof-3\n");
             if(b!=-1)  //not needed
              {
                o->write("toks[b-2] is %O\n",toks[b-2]);
                o->write("myvars[toks..] is %O\n",base_objects(this)[toks[b-2]]);
                
                if((myvars[toks[b-2]]))   //usually it is like x->y->z->set_attribute(""), so z will be our constant which is -2 from loc.
                {
                  o->write("object is %O\n",base_objects(this)[toks[b-2]]);
                  o->write("get_attributes completions\n");
                  completions = indices(base_objects(this)[toks[b-2]]->get_attributes());
                  string rest = toks[b+1][1]-"\"";
                  if(rest!="")
                  {
                    o->write("inside toks[1]\n");
                    array(string) temp = ({ });
                    int i = 0;
                    int l = sizeof(rest);
                    foreach(completions, string str)
                    {
                     if(str[0 .. (l-1)]==rest)
                     {
                       o->write("String : "+str+"\n");
                       temp = temp + ({str});
                       i++;
                     }
                    }
                    if(sizeof(temp)==1)
                      completions = (string)(temp[0]-rest);
                    else
                      completions = temp;
                   }
                   o->write("mycompletions is %O\n",completions);
                   flag = 1;
                }
              }
            }
          }
          if(flag==0)
          {
            mixed outer_error = catch{
              o->write("tokenizing now \n");
              array tokens3 = ({ });
              mixed error = catch{
                        tokens3 = tokenize(input+"\")");
              };
              o->write("tokens3 3 3  here are %O\n",tokens3);
              if(error==0)
              {
                int a = 0;
                o->write("No error in tokenizing\n");
                if((a=search(tokens3,"OBJ"))!=-1)
                {
                  o->write("found OBJ at %O",a);
                  o->write("adding 1 now\n");
                  int b = a+1;
                  o->write("b is %O\n",b);
                  o->write("tokens[a+1] is %O\n",tokens3[b]);
                  if(arrayp(tokens3[b]))
                  {
                    o->write("going to show_path_completions\n");
                    completions = show_path_completions(tokens3[a+1][1]);
                  }
                  else
                    throw("no toks[a+1]\n");
                }
              }
            };
            if(outer_error)
              completions = get_file_completions((input/"\"")[-1]);
          }
        };
      }

  //DONT NEED THIS, happens already internally. 

/*      //IMPLEMENTING OBJ(coder-> , basically wherever obj-> is not first
      if(input[-2]=='-'&&input[-1]=='>')
      {
        o->write("CAME INSIDE line 277, for last element being ->\n");
        array tokens2 = ({});
        mixed error2 = catch
        {
          tokens2 = tokenize(input+")");
          o->write("tokens2 are %O\n",tokens);
        };
        if(!error2)
        {
          if(tokens2[-1][-2]=="->")   //it is an array inside tokens with (, coder, ->, ) at the end where tab is pressed.
          {
            completions = get_module_completions(({ tokens2[-1][-3], tokens2[-1][-2] }));
            o->write("COMPLETIONS FOR NOW : %O\n",completions);
          }
        }
        else
          o->write("some error for tokenize again\n");
      }
*/
      if (error)
      {
        if(!objectp(error))
          error = Error.mkerror(error);
        readln->message(sprintf("%s\nAn error occurred, attempting to complete your input!\nPlease include the backtrace above and the line below in your report:\ninput: %s\n", error->describe(), input));
        completions = ({});
      }
    }
    //o->write("Completions1 : %O\n",completions);

    if (tokens && !completions)
    {
      array completable = get_resolvable(tokens, variables->DEBUG_COMPLETIONS);
      //o->write("Completable : %O\n",completable);
      if (completable && sizeof(completable))
      {
        error = catch
        {
          completions = get_module_completions(completable);
         o->write("our completions : %O\n",completions);
        };
        error = Error.mkerror(error);
      }
      else if (!tokens || !sizeof(tokens))
        completions = sort(indices(master()->root_module)) +
          sort(indices(base_objects(this)));
        // FIXME: base_objects should not be sorted like this
      o->write("completions2 : %O\n",completions);
      if (!completions || !sizeof(completions))
      {
        string token = tokens[-1];
        if( sizeof(tokens) >= 2 && typeof_token(token) == "whitespace" )
          token = tokens[-2];

        if (variables->DEBUG_COMPLETIONS)
          readln->message(sprintf("type: %s\n", typeof_token(token)));

        completions = sort(indices(master()->root_module)) +
          sort(indices(base_objects(this)));
        o->write("completions3 : %O\n",completions);

        switch(typeof_token(token))
        {
          case "symbol":
          case "literal":
          case "postfix":
            completions = (array)(infix+seperator);
            break;
          case "prefix":
          case "infix":
          case "seperator":
          default:
            completions += (array)prefix;
        }
        o->write("completions4 : %O\n",completions);
        foreach(reverse(tokens);; string token)
        {
            if (group[token])
            {
              completions += ({ group[token] }) ;
              break;
            }
        }
        o->write("completions5 : %O\n",completions);
      }

      if (error)
      {
        readln->message(sprintf("%s\nAn error occurred, attempting to complete your input!\nPlease include the backtrace above and the lines below in your report:\ninput: %s\ntokens: %O\ncompletable: %O\n", error->describe(), input, tokens, completable, ));
      }
      else if (variables->DEBUG_COMPLETIONS)
        readln->message(sprintf("input: %s\ntokens: %O\ncompletable: %O\ncompletions: %O\n", input, tokens, completable, completions));
    }
    handler->show_errors();
    handler->show_warnings();
    master()->set_inhibit_compile_errors(old_handler);
//    write("Completions are %O",completions);
    if(completions && sizeof(completions))
    {
      if(stringp(completions))
      {
        readln->insert(completions, readln->getcursorpos());
      }
      else
      {
        readln->list_completions(completions);
      }
    }
    //o->write("Completions : %O\n",completions);
  }

mixed show_path_completions(string cur_path)
{
  cur_path = cur_path - "\"";   //trimming "s in suppose "/"-> /
  o->write("cur path is "+cur_path+"\n");
  mixed demo = ({ });
  if(cur_path=="")
  {
      demo = "/";
  }
  else
  {
    o->write("trying to access server filepath object\n");
    string rest="";
    array parts = ({});
    parts = cur_path/"/";
    if(sizeof(parts)!=2)
    {
      cur_path = parts[0 .. sizeof(parts)-2]*"/";
      rest = parts[-1];
    }
    else
    {
      cur_path="/";
      rest = parts[1];
    }
    o->write("server is %O\n",server_fp);
    object a;
    mixed error2 = catch{
      a = server_fp->path_to_object(cur_path);
    };
    o->write("cur_path object is %O\n",a);
    array objs = ({ });
    mixed error= catch{
    o->write("came in catch stmnt\n");
      string x_s="";
      objs=a->get_inventory();
      foreach(objs, object x)
      {
        if(cur_path!="/")
          x_s = x->query_attribute("OBJ_PATH") - cur_path - "/";
        else
          x_s = x->query_attribute("OBJ_PATH") - "/";
        mixed error3 = catch{
          if(x_s[0 .. sizeof(rest)-1]==rest)
            demo = demo + ({ x_s });
        };
      }
      o->write("SIZEOF (DEMO) is %O\n",sizeof(demo));
      if(sizeof(demo)==1)
      {
        demo = demo[0]-(rest);
        o->write("demo[0] is "+demo);
        if(demo=="")
          demo = "/";
      }
    };
  }
  return demo;
}

mapping reftypes = ([ "module":".",
                     "object":"->",
                     "mapping":"->",
                     "function":"(",
                     "program":"(",
                     "method":"(",
                     "class":"(",
                   ]);

array low_get_module_completions(array completable, object base, void|string type, void|int(0..1) space)
{
  o->write("came in low_get\n");
  if (variables->DEBUG_COMPLETIONS)
    safe_write(sprintf("low_get_module_completions(%O\n, %O, %O, %O)\n", completable, base, type, space));

  if (!completable)
    completable = ({});

  mapping other = ([]);
  array modules = ({});
  mixed error;

   if (base && !sizeof(completable))
   {
     if (space)
       return (array)infix;
     if (type == "autodoc")
       return ({ reftypes[base->objtype||base->objects[0]->objtype]||"" });
     if (objectp(base))
       return ({ reftypes[type||"object"] });
     if (mappingp(base))
       return ({ reftypes->object });
     else if(functionp(base))
       return ({ reftypes->function });
     else if (programp(base))
       return ({ reftypes->program });
     else
       return (array)infix;
   }

      if (!base && sizeof(completable) && completable[0] == ".")
      {
          o->write("[1]came in this if line 228\n");
          array modules = sort(get_dir("."));
          o->write("modules : %O\n",modules);
          if (sizeof(completable) > 1)
          {
            o->write("[2]came in the if inside that\n");
            modules = Array.filter(modules, has_prefix, completable[1]);
            o->write("modules : %O\n",modules);
            if (sizeof(modules) == 1)
              return ({ (modules[0]/".")[0][sizeof(completable[1])..] });
            string prefix = String.common_prefix(modules)[sizeof(completable[1])..];
            if (prefix)
              return ({ prefix });

            if (sizeof(completable) == 2)
              return modules;
            else
              return ({});
            o->write("if came here, then didn't return\n");
          }
          else
            return modules;
      }
      else if (!base)
      {
          if (type == "autodoc")
          {
            if (variables->DEBUG_COMPLETIONS)
              safe_write("autodoc without base\n");
            return ({});
          }
          other = base_objects(this);
          base = master()->root_module;
      }

      if (type == "autodoc")
      {
        if (base->docGroups)
          modules = Array.uniq(Array.flatten(base->docGroups->objects->name));
        else
          return ({});
      }
      else
      {
        error = catch
        {
          o->write("base is %O\n",base);
          modules = sort(indices(base));
          o->write("came in line 278\n");
          o->write("modules : %O\n",modules);
        };
        error = Error.mkerror(error);
      }

      if (sizeof(other))
        modules += indices(other);

      if (sizeof(completable) == 1)
      {
          if (type == "autodoc"
              && typeof_token(completable[0]) == "argumentgroup")
            if (space)
              return (array)infix;
            else
              return ({ reftypes->object });
          if (reference[completable[0]])
            return modules;
          if (!stringp(completable[0]))
            return ({});


          modules = sort((array(string))modules);
          o->write("After sorting\nmodules : %O\n",modules);
          modules = Array.filter(modules, has_prefix, completable[0]);
          o->write("After filtering\nmodules : %O\n",modules);
          string prefix = String.common_prefix(modules);
          o->write("prefix is "+prefix+"\n");
          string module;

          if (prefix == completable[0] && sizeof(modules)>1 && (base[prefix]||other[prefix]))
            return modules + low_get_module_completions(({}), base[prefix]||other[prefix], type, space);
          o->write("CAME HERE means  did not return\n");
          prefix = prefix[sizeof(completable[0])..];
          if (sizeof(prefix))
            return ({ prefix });

          if (sizeof(modules)>1)
            return modules;
          else if (!sizeof(modules))
            return ({});
          else
          {
            module = modules[0];
            modules = ({});
            object thismodule;

            if(other && other[module])
            {
              thismodule = other[module];
              type = "object";
            }
            else if (intp(base[module]) || floatp(base[module]) || stringp(base[module]) )
              return (array)infix;
            else
            {
              thismodule = base[module];
              if (!type)
                type = "module";
            }

            return low_get_module_completions(({}), thismodule, type, space);
          }
      }

      if (completable && sizeof(completable))
      {
          if ( (< "reference", "argumentgroup" >)[typeof_token(completable[0])])
            return low_get_module_completions(completable[1..], base, type||reference[completable[0]], space);
          else
            safe_write(sprintf("UNHANDLED CASE: completable: %O\nbase: %O\n", completable, base));
      }

      return modules;
  }

  array|string get_module_completions(array completable)
  {
    array rest = completable;
    object base;
    string type;
    int(0..1) space;

    if (!completable)
      completable = ({});

    if (completable[-1]==' ')
    {
      space = true;
      completable = completable[..<1];
    }
    o->write("completable is %O\n",completable);
    if (sizeof(completable) > 1)
      [base, rest, type] = resolv(this, completable);
    o->write("base : %O\nrest : %O\n",base,rest);
    o->write("type : "+type+"\n");

    if (variables->DEBUG_COMPLETIONS)
      safe_write(sprintf("get_module_completions(%O): %O, %O, %O\n", completable, base, rest, type));
    array completions = low_get_module_completions(rest, base, type, space);
//  o->write("completions from module : %O\n",completions);
    if (sizeof(completions) == 1)
      return completions[0];
    else
      return completions;
  }
  array|string get_file_completions(string path)
  {
    array files = ({});
    if ( (< "", ".", ".." >)[path-"../"] )
      files += ({ ".." });
    o->write("files : %O\n",files);

    if (!sizeof(path) || path[0] != '/')
      path = "./"+path;

    string dir = dirname(path);
    if(dir)
        o->write("dir is "+dir+"\n");
    string file = basename(path);
    if(file)
        o->write("file is "+file+"\n");
    catch
    {
      files += get_dir(dir);
    };
    o->write("files2 : %O\n",files);

    if (!sizeof(files))
      return ({});

    array completions = Array.filter(files, has_prefix, file);
    //o->write("completions in get_file : %O\n",completions);
    string prefix = String.common_prefix(completions)[sizeof(file)..];
    o->write("prefix is "+prefix+"\n");
    if (sizeof(prefix))
    {
      return prefix;
    }

    mapping filetypes = ([ "dir":"/", "lnk":"@", "reg":"" ]);

    if (sizeof(completions) == 1 && file_stat(dir+"/"+completions[0])->isdir )
    {
      return "/";
    }
    else
    {
      foreach(completions; int count; string item)
      {
        Stdio.Stat stat = file_stat(dir+"/"+item);
        if (stat)
          completions[count] += filetypes[stat->type]||"";

        stat = file_stat(dir+"/"+item, 1);
        if (stat->type == "lnk")
          completions[count] += filetypes["lnk"];
      }
      return completions;
    }
  }

