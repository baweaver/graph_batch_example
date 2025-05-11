# README

Experimental repo to test GraphQL batch loading patterns.

## Sample Query

Try this out in local [GraphiQL](http://127.0.0.1:3000/graphiql)

### Association Field

Plain data, nothing fancy

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

It should have ~9 queries if this works properly. Need to add tests to verify

### Connections

```
{
  posts {
    id
    title
    commentsConnection(first: 5) {
      edges {
        node {
          id
          body
          spam
          author {
            id
            name
            profile {
              id
              bio
            }
          }
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
  }
}
```
