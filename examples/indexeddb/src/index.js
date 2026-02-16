import * as ConcurrentTask from "@andrewmacmurray/elm-concurrent-task";
import { createTasks } from "../../../elm-indexeddb/js/src/index.js";

const app = window.Elm.Main.init({ node: document.getElementById("app") });

ConcurrentTask.register({
  tasks: createTasks(),
  ports: {
    send: app.ports.send,
    receive: app.ports.receive,
  },
});
