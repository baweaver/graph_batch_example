# frozen_string_literal: true

require "rails_helper"

RSpec.describe "AssociationDataloaderWithLookahead integration" do
  it "eager loads nested associations using dataloader and lookahead" do
    author = FactoryBot.create(:author, name: "Test Author")
    profile = FactoryBot.create(:profile, author:)
    post = FactoryBot.create(:post, title: "GraphQL Rocks")
    comment = FactoryBot.create(:comment, author:, post:, body: "Nice", spam: false)

    query = <<~GRAPHQL
      {
        posts {
          id
          title
          comments {
            id
            author {
              id
              name
              profile {
                id
                bio
              }
            }
          }
        }
      }
    GRAPHQL

    result = GraphBatchSchema.execute(query)

    expect(result["errors"]).to be_nil

    post_data = result.dig("data", "posts", 0)

    expect(post_data["title"]).to eq("GraphQL Rocks")

    first_comment_author = post_data.dig("comments", 0, "author")
    expect(first_comment_author["name"]).to eq("Test Author")
    expect(first_comment_author["profile"]["id"]).to eq(profile.id.to_s)
  end

  it "paginates comments with first: 2" do
    author = FactoryBot.create(:author, name: "Paginated Author")
    post = FactoryBot.create(:post, title: "Paginated Post")
    5.times { |i| FactoryBot.create(:comment, author:, post:, body: "Comment #{i}", spam: false) }

    query = <<~GRAPHQL
      {
        posts {
          id
          commentsConnection(first: 2) {
            edges {
              node {
                id
                body
              }
            }
            pageInfo {
              hasNextPage
            }
          }
        }
      }
    GRAPHQL

    result = GraphBatchSchema.execute(query)

    connection = result.dig("data", "posts", 0, "commentsConnection")
    comments = connection["edges"]
    expect(comments.size).to eq(2)

    expect(connection["pageInfo"]["hasNextPage"]).to eq(true)
  end

  it "filters out spam comments" do
    author = FactoryBot.create(:author, name: "Filter Author")
    post = FactoryBot.create(:post, title: "Filter Post")
    FactoryBot.create(:comment, author:, post:, body: "Real comment", spam: false)
    FactoryBot.create(:comment, author:, post:, body: "Spam comment", spam: true)

    query = <<~GRAPHQL
      {
        posts {
          id
          commentsConnection(first: 10) {
            edges {
              node {
                id
                body
              }
            }
          }
        }
      }
    GRAPHQL

    result = GraphBatchSchema.execute(query)
    connection = result.dig("data", "posts", 0, "commentsConnection")
    bodies = connection["edges"].map { |edge| edge["node"]["body"] }
    expect(bodies).to include("Real comment")
    expect(bodies).not_to include("Spam comment")
  end

  it "eager loads deeply nested associations" do
    user = FactoryBot.create(:user, name: "Deep User")
    author = FactoryBot.create(:author, name: "Deep Author")
    profile = FactoryBot.create(:profile, author:)
    post = FactoryBot.create(:post, title: "Deep Post")
    comment = FactoryBot.create(:comment, author:, post:, body: "Deep", spam: false)
    like = FactoryBot.create(:like, comment:, user:)

    query = <<~GRAPHQL
      {
        posts {
          comments {
            author {
              profile {
                bio
              }
            }
            likes {
              user {
                name
              }
            }
          }
        }
      }
    GRAPHQL

    result = GraphBatchSchema.execute(query)
    like_user_name = result["data"]["posts"].first["comments"].first["likes"].first["user"]["name"]
    expect(like_user_name).to eq("Deep User")
  end

  it "handles posts with no comments" do
    FactoryBot.create(:post, title: "Empty Post")

    query = <<~GRAPHQL
      {
        posts {
          id
          commentsConnection(first: 10) {
            edges {
              node {
                id
                body
              }
            }
          }
        }
      }
    GRAPHQL

    result = GraphBatchSchema.execute(query)
    edges = result["data"]["posts"].first["commentsConnection"]["edges"]
    expect(edges).to eq([])
  end

  it "handles nil profiles without crashing" do
    author = FactoryBot.create(:author, name: "No Profile Author")
    post = FactoryBot.create(:post, title: "Post Without Profile")
    FactoryBot.create(:comment, author:, post:, body: "Missing profile", spam: false)

    query = <<~GRAPHQL
      {
        posts {
          comments {
            author {
              name
              profile {
                id
                bio
              }
            }
          }
        }
      }
    GRAPHQL

    result = GraphBatchSchema.execute(query)
    profile = result["data"]["posts"].first["comments"].first["author"]["profile"]
    expect(profile).to be_nil
  end

  it "safely handles missing lookahead for a field" do
    author = FactoryBot.create(:author, name: "Fallback Author")
    post = FactoryBot.create(:post, title: "Fallback Post")
    FactoryBot.create(:comment, author:, post:, body: "Fallback", spam: false)

    query = <<~GRAPHQL
      {
        posts {
          comments {
            body
          }
        }
      }
    GRAPHQL

    result = GraphBatchSchema.execute(query)
    bodies = result["data"]["posts"].first["comments"].map { |c| c["body"] }
    expect(bodies).to include("Fallback")
  end

  # You'd have to add this concept
  xit "resolves polymorphic associations correctly" do
    # Assuming Like belongs_to :likable, polymorphic: true
    user = FactoryBot.create(:user, name: "Polymorphic User")
    post = FactoryBot.create(:post, title: "Polymorphic Post")
    like = FactoryBot.create(:like, user:, likable: post)

    query = <<~GRAPHQL
      {
        likes {
          id
          user {
            id
            name
          }
        }
      }
    GRAPHQL

    result = GraphBatchSchema.execute(query)
    like_user = result["data"]["likes"].first["user"]
    expect(like_user["name"]).to eq("Polymorphic User")
  end
end
