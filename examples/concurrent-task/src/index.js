import * as ConcurrentTask from "@andrewmacmurray/elm-concurrent-task";

const app = window.Elm.Main.init({ node: document.getElementById("app") });

ConcurrentTask.register({
  tasks: {
    "localstorage:getItem": getItem,
    "localstorage:setItem": setItem,
  },
  ports: {
    send: app.ports.send,
    receive: app.ports.receive,
  },
});

function getItem({ key }) {
  try {
    const item = localStorage.getItem(key);
    if (item === null) {
      return { error: "NO_VALUE" };
    }
    return item;
  } catch (e) {
    return { error: "READ_BLOCKED" };
  }
}

function setItem({ key, value }) {
  localStorage.setItem(key, value);
}
