# README

Experimental repo to test GraphQL batch loading patterns.

## Sample Query

Try this out in local [GraphiQL](http://127.0.0.1:3000/graphiql):

```
{
  posts {
    id
    title
    comments {
      id
      body
      author {
        id
        name
        profile {
          id
          bio
        }
      }
      post {
        id
        title
        comments {
          id
          likes {
            id
            user {
              id
              name
            }
          }
        }
      }
    }
    tags {
      id
      name
    }
  }
}
```

It should have ~22 queries if this works properly. Need to add tests to verify
