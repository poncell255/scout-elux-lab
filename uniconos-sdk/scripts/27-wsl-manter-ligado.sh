#!/bin/bash
# Roda pela tarefa agendada "WSL GLPI" no boot do Windows: liga o Docker (sobe o GLPI) e mantem o WSL ligado.
service docker start > /dev/null 2>&1
exec sleep infinity
