// The review page (spec 0016). Reads the token from the link's fragment, removes
// it from the address bar, asks the review-application function for the
// application, and sends Approve or Reject. Everything from the server is shown
// as text, never as HTML.
(function () {
  "use strict";

  var endpoint = window.REVIEW_CONFIG.endpoint;
  var $ = function (id) { return document.getElementById(id); };

  // The token lives in the fragment so no server or log ever sees it. Keep it in
  // memory only, and take it out of the address bar and the history entry.
  var match = /(?:^|[#&])t=([A-Za-z0-9_-]+)/.exec(window.location.hash);
  var token = match ? match[1] : null;
  window.history.replaceState(null, "", window.location.pathname + window.location.search);

  var MESSAGES = {
    invalid_link: "This link is no longer valid.",
    already_decided: "This application was already decided.",
    already_seller: "This person is already a seller, so it cannot be approved. You can reject it instead.",
    username_taken: "The username was taken by someone else in the meantime. You can reject it instead.",
    reason_required: "Write a reason of up to 500 characters.",
    failed: "Something went wrong. Try again in a moment.",
    network: "Could not reach the server. Check your connection and try again."
  };

  function say(text, isError) {
    var el = $("message");
    el.textContent = text;
    el.hidden = false;
    if (isError) el.setAttribute("role", "alert");
  }

  function call(action, reason) {
    return fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ token: token, action: action, reason: reason })
    }).then(function (response) {
      return response.json().then(function (body) { return { ok: response.ok, body: body }; });
    });
  }

  function row(label, value) {
    if (!value) return;
    var wrap = document.createElement("div");
    wrap.className = "row";
    var dt = document.createElement("dt");
    dt.textContent = label;
    var dd = document.createElement("dd");
    dd.textContent = value;
    wrap.appendChild(dt);
    wrap.appendChild(dd);
    $("details").appendChild(wrap);
  }

  var KINDS = { id: "ID photo", business: "Business registration", logo: "Store logo" };

  function show(data) {
    var a = data.application;
    row("Kind", a.origin === "visitor" ? "Visitor, no account" : "Signed in account");
    row("Status", a.status);
    row("Store name", a.storeName);
    row("Username", a.username);
    row("Location", a.location);
    row("About", a.bio);
    row("Website", a.websiteUrl);
    row("Store phone", a.contactPhone);
    row("Store email", a.contactEmail);
    row("Applicant name", a.applicantName);
    row("Applicant email", a.applicantEmail);
    row("Applicant phone", a.applicantPhone);
    row("Sent", a.createdAt);

    data.photos.forEach(function (photo) {
      var figure = document.createElement("figure");
      figure.className = "photo";
      var caption = document.createElement("figcaption");
      caption.textContent = KINDS[photo.kind] || "File";
      figure.appendChild(caption);
      if (photo.image) {
        var img = document.createElement("img");
        img.src = photo.url;
        img.alt = caption.textContent;
        img.referrerPolicy = "no-referrer";
        figure.appendChild(img);
      } else {
        var link = document.createElement("a");
        link.href = photo.url;
        link.target = "_blank";
        link.rel = "noopener noreferrer";
        link.textContent = "Open the file";
        figure.appendChild(link);
      }
      $("photos").appendChild(figure);
    });
    if (!data.photos.length) $("photos").textContent = "No photos could be loaded.";

    if (a.status !== "reviewing") {
      $("actions").hidden = true;
      say("This application was already decided (" + a.status + ").", false);
    }
    $("status").hidden = true;
    $("application").hidden = false;
  }

  function finish(text) {
    $("application").hidden = true;
    $("status").hidden = true;
    say(text, false);
  }

  function decide(action, reason, buttons) {
    buttons.forEach(function (b) { b.disabled = true; });
    call(action, reason).then(function (result) {
      if (result.ok) {
        finish(result.body.status === "approved"
          ? "Approved. The application is decided."
          : "Rejected. The application is decided.");
        return;
      }
      buttons.forEach(function (b) { b.disabled = false; });
      var code = result.body && result.body.error;
      if (code === "invalid_link" || code === "already_decided") {
        finish(MESSAGES[code]);
      } else {
        say(MESSAGES[code] || MESSAGES.failed, true);
      }
    }).catch(function () {
      buttons.forEach(function (b) { b.disabled = false; });
      say(MESSAGES.network, true);
    });
  }

  function toggle(id, open) {
    $("confirm-approve").hidden = true;
    $("confirm-reject").hidden = true;
    $("message").hidden = true;
    if (open) $(id).hidden = false;
    $("actions").hidden = !!open;
    if (open) {
      var first = $(id).querySelector("textarea, button");
      if (first) first.focus();
    }
  }

  $("approve").addEventListener("click", function () { toggle("confirm-approve", true); });
  $("reject").addEventListener("click", function () { toggle("confirm-reject", true); });
  Array.prototype.forEach.call(document.querySelectorAll("[data-cancel]"), function (b) {
    b.addEventListener("click", function () { toggle(null, false); });
  });

  $("confirm-approve").addEventListener("submit", function (event) {
    event.preventDefault();
    decide("approve", null, Array.prototype.slice.call($("confirm-approve").querySelectorAll("button")));
  });
  $("confirm-reject").addEventListener("submit", function (event) {
    event.preventDefault();
    var reason = $("reason").value.trim();
    if (!reason || reason.length > 500) {
      say(MESSAGES.reason_required, true);
      return;
    }
    decide("reject", reason, Array.prototype.slice.call($("confirm-reject").querySelectorAll("button")));
  });

  if (!token) {
    finish(MESSAGES.invalid_link);
    return;
  }
  call("view").then(function (result) {
    if (result.ok) {
      show(result.body);
    } else {
      finish(MESSAGES[result.body && result.body.error] || MESSAGES.failed);
    }
  }).catch(function () {
    finish(MESSAGES.network);
  });
})();
