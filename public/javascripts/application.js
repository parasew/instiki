// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults
function toggleView(id)
{
  (document.getElementById(id).style.display == 'block') ? document.getElementById(id).style.display='none' : document.getElementById(id).style.display='block';
}

