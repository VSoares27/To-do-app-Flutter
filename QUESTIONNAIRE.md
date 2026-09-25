# Mobile App Reverse-Engineering Questions

Answer the following questions based on the code generated during the exercise.

You may use the coding agent to help investigate the project, but you must inspect the source code and verify the answers yourself.

Whenever possible, mention the relevant files, classes, functions, or components.

---

## 1. Project Structure

What are the main parts of the project, and where can you find:

- UI/screens;
- data models;
- SQLite/database code;
- navigation;
- notification code?

Briefly describe how the project is organized.

> **Resposta**
> 
>A estrutura do projeto está dividida em:
>
> - UI/screens: Pode ser encontrado na pasta `lib/screens`, onde estão os arquivos TaskListScreen (Responsável pela listagem das tarefas na tela principal), CategoryFilterSheet (Responsável por filtrar as tarefas por categoria), TaskEditorScreen (Responsável por editar as tarefas).
> - Data models: Pode ser encontrado na pasta `lib/models`, onde estão os arquivos Task (Responsável por definir a estrutura de uma tarefa) e Category (Responsável por definir a estrutura de uma categoria).
> - SQLite/database code: Pode ser encontrado na pasta `lib/data`, onde estão os arquivos AppDatabase (Responsável por criar o banco de dados), TaskRepository (Responsável por criar, ler, atualizar e deletar tarefas) e CategoryRepository (Responsável por criar, ler, atualizar e deletar categorias).
> - Navegation: Pode ser encontrado na pasta `lib/navigation`, onde estão os arquivos AppRouter (Responsável por gerenciar a navegação entre telas) e TaskRoute (Responsável por gerenciar rotas).
> - Notification code: Pode ser encontrado na pasta `lib/services`, onde está o arquivo NotificationService.

---

## 2. Architecture and State

How is application state managed?

Explain how the UI is updated after an operation such as:

- creating a task;
- editing a task;
- marking a task as completed.

Does the project use any recognizable architectural pattern or state-management approach?

---

> **Resposta**
>
> O estado do aplicativo é gerenciado pelo AppState, que é uma classe ChangeNotifier responsável por manter o estado atual do aplicativo. Ele é utilizado para manter o estado atual do aplicativo, como as tarefas e categorias, bem como os filtros aplicados. O padrão de arquitetura utilizado é o MVVM (Model-View-ViewModel).

## 3. SQLite Persistence

How is SQLite used in the application?

Identify:

- where the database is created;
- how tasks and categories are stored;
- where create, read, update, and delete operations are implemented.

---

> **Resposta**
>
> O banco de dados é criado pelo AppDatabase na pasta `lib/data/app_database.dart`, que é uma classe que estende Database. Ele é utilizado para criar o banco de dados e as tabelas necessárias para armazenar as tarefas e categorias.

## 4. Follow One Operation

Trace what happens when the user creates a new task.

Start from pressing **Save** and follow the execution until:

1. the task is stored in SQLite;
2. the task appears in the task list;
3. a notification is scheduled, if a due date exists.

Describe the main functions/components involved.

---

> **Resposta**
>
> O processo de criação de uma nova tarefa envolve:
>
> - O usuário preenche os campos do formulário na Tela de edição da task.
> - Ao pressionar o botão Salvar, o método _saveTask é chamado, que cria uma nova tarefa com os dados fornecidos.
> - A tarefa é salva no banco de dados SQLite através do método insert do TaskRepository.
> - Em seguida, o estado do aplicativo é atualizado para incluir a nova tarefa, e a lista de tarefas é recarregada.
> - A tarefa aparece na lista de tarefas na Tela principal, e uma notificação é agendada, se um prazo foi definido.

## 5. Navigation

How does navigation between screens work?

In particular:

- how does the app navigate from the task list to the task editor?
- when editing a task, what information is passed between screens?

For example: task ID, full object, shared state, or another approach.

---

> **Resposta**
>
> A navegação entre telas é gerenciada pelo AppRouter na pasta `lib/navigation`, que é uma classe que estende Router. Ele é utilizado para gerenciar a navegação entre telas, como a navegação da tela principal para a tela de edição da task.

## 6. Notifications

How are task reminders implemented?

Explain:

- how a notification is scheduled;
- how it is associated with a task;
- what happens when the due date changes;
- what happens when the task is completed or deleted.

---

> **Resposta**
>
> O processo da notificação se inicia quando é criada uma task com um prazo de data e hora definidos. Após isso, a notificação é preparada por `NotificationService` e agendada utilizando o `flutter_local_notifications`. Quando uma task é concluída ou deletada, a notificação é cancelada. 

## 7. Agent Decisions

Identify at least **two important decisions made by the coding agent that were not explicitly specified in the assignment**.

Examples:

- architecture;
- libraries;
- state-management strategy;
- navigation approach;
- SQLite abstraction;
- project structure.

For each one, explain what the agent chose.

---

> **Resposta**
>
> O agente de IA optou por usar uma arquitetura de camadas leves por ser um app simples com o intuito educacional. Além disso, para o banco de dados foi utilizado o SQLite para persistência dos dados localmente, diminuindo a complexidade do projeto e geração de códigos.

## 8. BUILD_LOG Analysis

Using `BUILD_LOG.md`, identify:

- one problem or bug encountered during development;
- how the agent attempted to solve it;
- whether the first solution worked;
- what was eventually done.

Then answer:

**What did the build log help you understand that would have been harder to discover by looking only at the final code?**

> **Resposta**
>
> O build log ajudou a entender o processo de desenvolvimento do projeto, as decisões tomadas pelo agente de IA e os problemas encontrados durante o desenvolvimento. Além disso, a partir do log, foi possível entender um pouco da sintaxe da linguagem aplicada ao projeto e permitiu que nós compreendesse como funcionava o código.
>

