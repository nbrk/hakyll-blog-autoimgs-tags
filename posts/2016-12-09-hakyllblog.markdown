---
title: Простой и удобный личный web-блог с Hakyll за десять минут
headerImg: 2016-12-09-hakyllblog.png
tags: hakyll
---

> Static sites are fast, secure, easy to deploy, and manageable using version control.

Получение сайта
===============
На машине для написания статей и генерации содержимого блога устанавливаем Haskell-окружение:

~~~ bash
# установка нужных программ средствами ОС
sudo pkg install -y stack git

# установка нужных haskell-библиотек 
stack install hakyll
~~~

Создаём директорию с проектом^[На некоторых системах stack помещает бинарники в `~/.local/bin` , что может не входить в юзерский $PATH] и генерим наш сайт:

~~~ bash
# шаблон hakyll-проекта
hakyll-init my-site

cd my-site

# инициализация stack-проекта с имеющимся резолвером (снэпшотом haskell-платформы)
stack init --resolver lts-3.5
# строим программу-генератор
stack build

# генерим наш сайт
stack exec site build

# просматриваем наш блог в браузере (http://127.0.0.1:8000)
stack exec site watch
~~~

Вот так выглядит ванильный блог Hakyll:

![](../static/img/vanilla-hakyll.png)

На данном этапе мы уже получили полноценный блог-сайт и можем писать в него, создавая новые markdown-файлы в директории `posts/` и 
регенерируя содержимое с `stack exec site build`. После каждой регенерации директория `_site` будет содержать текущую версию нашего блога; содержимое этой директории
полностью готово к закачиванию на web-сервер!

	about.html
	archive.html
	contact.html
	css/
	images/
	index.html
	posts/

Как видим, для содержания такого блога никаких знаний Haskell не требуется.


Помещение сайта в систему контроля версий git
=============================================
Некоторые блогеры могут закончить на прошлом шаге, но мы идём дальше и хотим поместить наш сайт в систему контроля версий, например git. Мы будем держать две ветки в репо:

1. ветку "hakyll" для отслеживания исходников сайта: наших постов (`.markdown`-файлов) и файлов hakyll (`.hs`-файлы, HTML-шаблоны, CSS, картинки, и т.д.)
2. ветку "master" для отслеживания нашего wwwroot: чистой, готовой к публикации на любой web-сервер директории с текущим сайтом (готовые HTML-файлы, CSS, картинки, и т.д.)

### Бесплатный хостинг web-сайтов на github.io
Разумеется, подойдёт любая система контроля версий (svn, darcs, и т.д.), но мы выбрали git чтобы продемонстрировать работу нашего сайта, воспользовавшись бесплатным
web-хостингом проектов с [Github](http://github.com).

Если пользователь гитхаба `user` создаёт пеозиторий на github.com и называет его специальным именем `user.github.io`, то по web-адресу

	http://user.github.io

автоматически будет доступен текущий срез ветки "master" нашего проекта `user.github.io`. Если в ветке окажется файлик `index.html`, то web-серверы github автоматически 
отдадут его web-клиенту и мы получим бесплатный хостинг с именем домена третьего уровня `<наше_имя>.github.io`. Более тонкая настройка GitHub Pages доступна в параметрах
репозитория на сайте Github.

Предположим, что наше github-имя звучит `my-site` и мы хотим получить блог на `my-site.github.io`.

### Настройка git для нашего блога
Для начала мы создаём новый проект (репозиторий) `my-site.github.io` на github.com и в настройках проекта добавляем свой публичный ключ (`~/.ssh/id_rsa.pub`) с правами на запись в репо, чтобы каждый раз не вводить пароль. Далее, инициализируем локальный репозиторий в директории нашего блога, не забыв создать файл `.gitignore` со списком объектов,
которые мы **не** хотим помещать под контроль версий (сюда относятся промежуточные файлы Haskell и stack, используемые для сборки программы-генератора на локальшной машине).

~~~ bash
# файлы Haskell-проектов, обычно исключаемые из контроля версий
cat > .gitignore
~~~

~~~
# Created by https://www.gitignore.io/api/haskell
TAGS
*~

### Haskell ###
dist
cabal-dev
*.o
*.hi
*.chi
*.chs.h
*.dyn_o
*.dyn_hi
.hpc
.hsenv
.cabal-sandbox/
cabal.sandbox.config
*.prof
*.aux
*.hp
.stack-work/
_cache/
_site/
.DS_Store
~~~

Итак, инициализируем локальный и удалённый репозиторий.

~~~ bash
# инит репо в директории блога
git init
git add -A
git commit -m "Initial commit"
git remote add origin git@github.com:<имя-пользователя-гитхаб>/<имя-репозитория>.github.io.git

# мы находимся в директории нашего блога и подготовили репо

# метим текущие файлы веткой "hakyll", веткой исходника блога
git checkout -b hakyll
git push -u origin hakyll

# возвращаемся на ветку "master", где мы будем хранить файлы для web-сервера
git checkout master

# удаляем все файлы с этой ветки (мы хотим хранить здесь только содержимое _site/)
rm -rf *
rm .ghci
git add -A
git commit -m "Delete all files"
git push -u origin master
~~~

Удалённый репозиторий подготовлен.

### Автоматизация процесса генерации-коммита-закачки блога
Всё готово. Мы можем обновлять наш блог следующим образом:

0. Убеждаемся, что работаем сейчас со свежей веткой "hakyll"
1. [Пишем в блог](2016-12-09-hakylladdpost.html) или редактируем предыдущие записи/добавляем/удаляем файлы, меняем css-стили или html-шаблоны, и т.д., пока не будем довольны результатом всего сайта на 127.0.0.1:8000
2. Перестраиваем haskell-программу (генератор нашего блога) и коммитим в "hakyll" изменения в исходниках блога (а также любые новые файлы и т.д.) 
3. Переключаемся на ветку "master" и удаляем *все* файлы (может быть, кроме `README.md` для сайта github.com)
4. Переключаемся на ветку "hakyll" и генерируем содержание сайта
5. Переключаемся на ветку "master" и коммитим все файлы из директории `_site`
6. (если не используем бесплатный хостинг на github.io) закачиваем файлы из ветки "master" на web-хостинг: в директорию нашего сайта на web-сервере 
7. Возвращаемся на ветку "hakyll" (в исходное состояния, шаг 0)

Однако лень так делать руками каждый раз, поэтому процесс нужно автоматизировать. Некто [ismailmustafa](http://ismailmustafa.com/posts/2016-01-24-hakyllSetup.html), 
чьи исходники блога я приспосабливал под себя, [написал](https://github.com/ismailmustafa/ismailmustafa.github.io/blob/hakyll/deploy) простенький скриптик "развёртывания" 
блога на `bash`. Я же немного подправил лентяйский скриптик для работы на обычном `/bin/sh`:

~~~ bash
# вся подобная работа только на ветке разработчика
git checkout -b hakyll

# сохраняем скриптик ниже в файл с именем "deploy"
touch deploy
chmod +x deploy
~~~

А вот и сам скриптик. Подправляем часть закачки^[Также важно обратить внимание, чтобы название программы после `stack exec` соответствовало названию cabal-пакета]
на хостинг (rsync) под себя или отключаем её вовсе, если наш сайт размещается на хостинге github.io.

~~~ bash
#!/bin/sh

error_exit()
{
    echo "$1" 1>&2
    exit 1
}

# Check if commit message argument
if [ -z "$1" ]
then
  echo "deploy script error: What changes did you make? Type a commit message."
  exit 1
fi

# Build successfuly or exit
stack clean
stack build || error_exit "deploy script error: Build failed"

# Push changes on hakyll branch to github
git add -A
git commit -m "$1" || error_exit "deploy script error: no changes to commit"
git push origin hakyll

# Switch to master branch
git checkout master

# delete old site
rm -rf *
git add -A && git commit -m "delete old site"

# switch to hakyll branch and rebuild website
git checkout hakyll
stack exec site rebuild

# switch to master, extract site and push
git checkout master
mv _site/* .
git add -A && git commit --amend -m "$1"
git push origin master

# rsync with remote wwwroot
rm -rf _site
rm -rf _cache
rsync -av * nbrk@linklevel.net:~/nbrk.linklevel.net.wwwroot

# return to original branch
git checkout hakyll
~~~

Написание первого поста в наш блог
==================================
Вот, собственно, и всё! Сделать запись -- [проще пареной репы](2016-12-09-hakylladdpost.html).

Например, так:

~~~ bash
cat > posts/2016-12-12-hello.markdown
~~~


    ---
    title: Привет, hakyll! 
    tags: блог, жизнь
    ---
    
    Кто-то ковыряется с `wordpress`, зависит от куч баз данных и милости хакеров. А я теперь знаю, что:
	
	> Static sites are fast, secure, easy to deploy, and manageable using version control.
	
	Вот так! А markdown *очень крут*. 

~~~ bash
# разворачиваем обновление
./deploy "add post about Hakyll"
~~~

Клонирование существующих блогов
================================
Такой приятный процесс управления личным сайтом посредством системы контроля версий, а также чёткое разделение генератора (т.е. функционала сайта), шаблонов 
(т.е. дизайна сайта) и markdown-файлов (т.е. содержания сайта) в системе Hakyll делают удобным клонирование уже существующих решений, на базе которых
можно строить всё более сложные и многофункциональные сайты.

На самом деле, блогеры сообщества Hakyll обожают так делать, и вы можете полностью склонировать большое количество разных репозиториев с блогами разнообразных 
дизайнов и функционалов, просто выберите полюбившийся из списка [People using Hakyll](https://jaspervdj.be/hakyll/examples.html).

Мой репозиторий базируется на скромном сайте [ismailmustafa](http://ismailmustafa.com/). Среди функций его блога автогенерация "фрактальных" (на самом деле нет) цветных
картинок к заголовкам постов. Я же добавил к этому поддержку тэгов (меток) в постах, а также страницу с облаком тэгов. Я выбросил из дизайна ненужные мне ссылки на социальные сети и немного подкрутил Open Graph параметры в <meta> для корректной вставки ссылок в пэйсбук.

Скачать исходники моего блога можно [тут](http://nbrk.linklevel.net/blog-sources.tgz). После распаковки архива можно сразу же делать записи в markdown и развёртывать блог
скриптом.
