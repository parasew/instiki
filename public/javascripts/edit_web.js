function proposeAddress() {
  document.getElementById('address').value =
    document.getElementById('name').value.replace(/[^a-zA-Z0-9]/g, "").toLowerCase();
}

function cleanAddress() {
  document.getElementById('address').value =
    document.getElementById('address').value.replace(/[^a-zA-Z0-9]/g, "").toLowerCase();
}

function checkSystemPassword(password) {
  if (password == "") {
    alert("You must enter the system password");
    return false;
  } else {
  	return true;
  }
}

function validateEditWebForm() {
  if (!checkSystemPassword(document.getElementById('system_password').value)) {
  	return false;
  }
  if (document.getElementById('name').value == "") {
    alert("You must pick a name for the web");
    return false;
  }
  if (document.getElementById('address').value == "") {
    alert("You must pick an address for the web");
    return false;
  }
  if (document.getElementById('password').value != "" &&
      document.getElementById('password').value != document.getElementById('password_check').value) {
    alert("The password and its verification doesn't match");
    return false;
  }
  return true;
}

// overriding auto-complete by form managers
// code by Chris Holland, lifted from 
// http://chrisholland.blogspot.com/2004/11/banks-protect-privacy-disable.html
function overrideAutocomplete() {
  if (document.getElementsByTagName) {
    var inputElements = document.getElementsByTagName("input");
    for (i=0; inputElements[i]; i++) {
      if (inputElements[i].className && (inputElements[i].className.indexOf("disableAutoComplete") != -1)) {
        inputElements[i].setAttribute("autocomplete","off");
      }//if current input element has the disableAutoComplete class set.
    }//loop thru input elements
  }
}

// This line is executed when the script is loaded
overrideAutocomplete();
